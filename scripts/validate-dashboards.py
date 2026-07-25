#!/usr/bin/env python3
"""Valida os dashboards Grafana provisionados por dashboards.tf.

Regras:
  1. JSON parseável, com uid e title.
  2. Nenhum matcher morto: os labels job/app nunca podem casar o nome antigo
     "auto-repair-shop" — os recursos k8s hoje se chamam order/billing/execution.
  3. Dashboard que declara a variável `service` deve usá-la em toda query.
  4. Valor de label de status/state/result/outcome/operation é UPPER_SNAKE, o que
     os ports de métrica garantem por serem enum.
"""
import json
import os
import re
import sys

DASHBOARD_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "modules", "k8s", "dashboards"
)
DEAD_MATCHER = re.compile(r'(job|app)\s*=~?\s*"[^"]*auto-repair-shop[^"]*"')
ENUM_LABEL = re.compile(r'\b(status|state|result|outcome|operation)\s*=~?\s*"([^"]+)"')


def queries(dashboard):
    """Toda expressão de query do dashboard, com o título do painel que a contém."""
    for panel in dashboard.get("panels", []):
        for sub in [panel] + panel.get("panels", []):
            for target in sub.get("targets", []):
                expr = target.get("expr") or target.get("query")
                if isinstance(expr, str) and expr.strip():
                    yield sub.get("title", "<sem titulo>"), expr


def validate(path):
    errors = []
    name = os.path.basename(path)
    try:
        with open(path, encoding="utf-8") as fh:
            dashboard = json.load(fh)
    except json.JSONDecodeError as exc:
        return [f"{name}: JSON invalido: {exc}"]

    for field in ("uid", "title"):
        if not dashboard.get(field):
            errors.append(f"{name}: campo '{field}' ausente ou vazio")

    variables = {v.get("name") for v in dashboard.get("templating", {}).get("list", [])}
    parameterized = "service" in variables

    for title, expr in queries(dashboard):
        dead = DEAD_MATCHER.search(expr)
        if dead:
            errors.append(f"{name} / {title}: matcher morto {dead.group(0)}")
        if parameterized and "$service" not in expr:
            errors.append(f"{name} / {title}: dashboard parametrizado mas a query nao usa $service")
        for label, value in ENUM_LABEL.findall(expr):
            for alternative in value.split("|"):
                bare = alternative.strip().strip(".*")
                if not bare or not re.fullmatch(r"[A-Za-z_]+", bare):
                    continue
                if bare != bare.upper():
                    errors.append(
                        f'{name} / {title}: valor de label {label}="{bare}" deveria ser UPPER_SNAKE'
                    )

    return errors


def main():
    if not os.path.isdir(DASHBOARD_DIR):
        print(f"diretorio nao encontrado: {DASHBOARD_DIR}", file=sys.stderr)
        return 1

    files = sorted(f for f in os.listdir(DASHBOARD_DIR) if f.endswith(".json"))
    if not files:
        print("nenhum dashboard encontrado", file=sys.stderr)
        return 1

    all_errors = []
    for f in files:
        errs = validate(os.path.join(DASHBOARD_DIR, f))
        all_errors.extend(errs)
        print(f"{'FAIL' if errs else 'ok  '}  {f}")

    for e in all_errors:
        print(f"  - {e}")

    print(f"\n{len(files)} dashboards, {len(all_errors)} problemas")
    return 1 if all_errors else 0


if __name__ == "__main__":
    sys.exit(main())
