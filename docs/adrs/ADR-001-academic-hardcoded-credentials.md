# ADR-001 — Credenciais padrão no contexto acadêmico

**Status:** Aceito em 2026-05-18

## Contexto

Grafana e seu banco no RDS precisam de credenciais. Operacionalizar rotação (External Secrets Operator, Sealed Secrets, `random_password`) adiciona infraestrutura sem benefício real num projeto sem usuários reais e com cluster recriado regularmente.

## Decisão

Senhas padrão (`admin`) como defaults nas variáveis Terraform. As strings não aparecem em nenhum arquivo commitado; vivem apenas nos defaults das variáveis. O RDS em ambos os ambientes tem `skip_final_snapshot = true` (não há dados a preservar).

## Consequências

- Zero overhead de gestão de segredos durante o projeto
- Não apto para produção real sem remover os defaults e adicionar rotação de segredos
