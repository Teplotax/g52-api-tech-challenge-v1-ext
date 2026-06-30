# g52-api-tech-challenge-v1-ext

Esse repo guarda o contrato OpenAPI da API do G52 | Tech Challenge, é o que vira a especificação importada no API Gateway da AWS (por isso o `-ext`, de extensions do `x-amazon-apigateway-integration`).

## Documentação da API

A especificação Swagger/OpenAPI é mantida no repositório [`doc-api-tech-challenge-v1`](https://github.com/Teplotax/doc-api-tech-challenge-v1) e publicada via **GitHub Pages**:

👉 https://teplotax.github.io/doc-api-tech-challenge-v1/

## Sobre a API

API de gerenciamento de ordens de serviço para oficinas mecânicas. Permite controlar o ciclo de vida completo de uma OS, desde a abertura até a entrega do veículo, além de gerenciar clientes, veículos, peças, insumos e serviços cadastrados.

### Ciclo de vida de uma OS

| De | Para | Ação |
|----|------|------|
| `RECEBIDA` | `EM_DIAGNOSTICO` | Iniciar diagnóstico |
| `EM_DIAGNOSTICO` | `AGUARDANDO_APROVACAO` | Solicitar aprovação: envia orçamento por e-mail ao cliente |
| `AGUARDANDO_APROVACAO` | `APROVADA` | Cliente aprova o orçamento (total ou parcial) |
| `APROVADA` | `EM_EXECUCAO` | Iniciar execução dos serviços |
| `EM_EXECUCAO` | `FINALIZADA` | Finalizar execução: consome estoque real e libera reservas |
| `FINALIZADA` | `ENTREGUE` | Entregar veículo: envia nota fiscal por e-mail e limpa tagChave |
| `CANCELADA` | `DEVOLVIDO` | Devolver veículo fisicamente: limpa tagChave |
| Qualquer status até `FINALIZADA` | `CANCELADA` | Cancelar OS: libera reservas de estoque |

> `ENTREGUE` e `DEVOLVIDO` são status terminais, nenhuma transição é permitida a partir deles.

### Gestão de estoque

O estoque de peças e insumos é controlado em duas camadas:

- **Estoque reservado** (`estoqueReservado`): reservado ao adicionar serviços à OS. Liberado ao cancelar ou finalizar.
- **Estoque real** (`estoque`): consumido definitivamente apenas na finalização da OS.

Ao cancelar uma OS, o que é liberado depende do status atual: antes de `APROVADA` libera a reserva de todos os serviços, a partir de `APROVADA` libera só a dos aprovados.

### Aprovação do orçamento

Ao solicitar aprovação, o sistema muda o status pra `AGUARDANDO_APROVACAO`, gera o orçamento em PDF e manda por e-mail com um link assinado (HMAC); o cliente aprova direto por ali, sem precisar logar. A aprovação pode ser total ou parcial.

### Recursos

| Recurso | Descrição |
|---------|-----------|
| **Ordens de Serviço** | Ciclo de vida completo da OS |
| **Clientes** | Cadastro e consulta de clientes |
| **Veículos** | Cadastro de veículos vinculados a clientes |
| **Peças** | Cadastro de peças com controle de estoque |
| **Insumos** | Cadastro de insumos com controle de estoque |
| **Serviços** | Catálogo de serviços oferecidos pela oficina |
| **Estoque** | Entrada e saída de estoque por EAN (batch) |

## Estrutura do repo

- `template-api-v1-ext.yaml`: arquivo principal do contrato (OpenAPI 3.0)
- `schemas/`, `responses/`, `examples/`, `parameters/`: pedaços reaproveitáveis referenciados via `$ref` no template
- `infra/`: Terraform que importa o spec resolvido no API Gateway (REST API já existente, gerenciada no repo de infra)

## Workflows (GitHub Actions)

Mesmo fluxo de branches dos outros repos do grupo (`feature → develop → release → main`), só que aqui o que rola é deploy do contrato, não de aplicação:

- **1 - Build & PR** (`feature/**` → `develop`): push numa `feature/*` abre PR pra `develop` automaticamente.
- **2 - Build and Deploy** (`develop`): empacota e resolve o OpenAPI (`redocly`), importa o spec resolvido no API Gateway via AWS CLI, roda o Terraform pra garantir o deploy do stage, sobe o spec resolvido pro repo de docs (`doc-api-tech-challenge-v1`) e cria a branch/PR de release.
- **3 - Promote & Deploy** (`release/**` → `main`): PR de `develop` pra `release/*` mergeado → abre PR de `release/*` pra `main` automaticamente.

Auth com AWS via OIDC, sem credenciais fixas.