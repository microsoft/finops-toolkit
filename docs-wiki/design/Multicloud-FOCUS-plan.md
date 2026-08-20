# Plano: tornar opcional a configuração de FOCUS AWS e Google na instalação do FinOps hub

> Escopo, justificativa e decisões de alto nível da feature. O detalhamento técnico — contrato do manifest, parâmetros Bicep, estrutura dos módulos e checklist de arquivos — está em [Multicloud-FOCUS-design](./Multicloud-FOCUS-design.md).
> Branch de trabalho: `arthursilvany/multicloud-focus`.

## Problema
Adicionar suporte opcional para ingestão de dados FOCUS de AWS e Google (GCP) durante a instalação do FinOps hub, sem transformar isso em um requisito do deployment padrão. O objetivo é permitir que uma implantação Azure do hub também receba dados multicloud em um fluxo de ingestão controlado, seguindo o modelo atual de extensões opcionais do template.

## Referências analisadas
- https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/hubs/deploy?tabs=azure-portal%2Cadx-dashboard#managed-exports
- https://techcommunity.microsoft.com/blog/finopsblog/getting-started-with-finops-hubs-multicloud-cost-reporting-with-azure-and-google/4415190
- Repositório atual: `src/templates/finops-hub/main.bicep`, `src/templates/finops-hub/modules/hub.bicep`, `src/templates/finops-hub/createUiDefinition.json`, `src/templates/finops-hub/modules/Microsoft.FinOpsHubs/RemoteHub/app.bicep`

## Conclusões do estudo
- O template atual já usa um padrão de flags opcionais para extensões de instalação (`enableManagedExports`, `enableRecommendations`, `remoteHubStorageUri`, `remoteHubStorageKey`).
- O arquivo `createUiDefinition.json` mostra que a UI do Azure Portal já expõe configurações opcionais em seções avançadas para cenários de hub remoto.
- O módulo `Microsoft.FinOpsHubs/RemoteHub/app.bicep` é o melhor padrão de referência do repositório para: (1) conectar um recurso externo ao Data Factory do hub; (2) sobrescrever datasets; e (3) manter o hub funcionando como ingestão centralizada.
- A documentação Microsoft cobre multicloud/remote hub para Azure, mas ainda não modela AWS e Google como configurações nativas e opcionais do instalador do FinOps hub. Há uma lacuna de experiência de deployment entre “Azure-only defaults” e “multicloud custom ingestion”.

## Direção do plano
1. Manter o deployment padrão do FinOps hub completamente Azure-first e sem mudanças de comportamento por default.
2. Adicionar um step opcional "Multicloud" no wizard, com toggles separados para AWS e Google.
3. Reaproveitar o Data Factory do hub como orquestrador para a coleta de arquivos FOCUS externos em vez de criar um deployment paralelo.
4. Tratar AWS/Google como “data sources extras” e não como recursos obrigatórios do hub.

## Revisão arquitetural após leitura do código (decisão principal)
O detalhamento está em `files/design-multicloud-focus.md`. A conclusão mudou o desenho original:

**Não construir um ETL paralelo.** O hub já possui a cadeia completa `msexports → Parquet → ingestion → ADX`, e ela é disparada por um `BlobEventsTrigger` que reage **exclusivamente** a `manifest.json` (`Microsoft.CostManagement/Exports/app.bicep:1712-1728`). Os schemas FOCUS 1.0/1.0r2/1.2 e os datasets para CSV, gzip e Parquet já existem.

Portanto o conector multicloud precisa apenas:
1. copiar os arquivos FOCUS do bucket S3/GCS para `msexports/<provider>/...`;
2. gravar por último um `manifest.json` compatível com o contrato do Cost Management.

Tudo depois disso — conversão, retenção e ingestão analítica — já funciona sem alteração. Isso reduz drasticamente o código novo e o custo de manutenção.

Padrão de referência a seguir: `Microsoft.Billing/Invoices`, o app opcional mais recente e completo do repositório (parâmetro `enableInvoiceDownload` + módulo condicional + step de UI + README + entrada no `.build.config`).

## Resultado dos spikes (concluídos)
Executados na branch `arthursilvany/multicloud-focus`. Detalhes em `files/design-multicloud-focus.md` §8b.

- **R1 — `exportConfig.resourceId`: refutado.** O ETL faz `split(toLower(resourceId), '/providers/microsoft.costmanagement/exports/')[0]` e usa o resultado apenas como segmento de caminho. Não há parsing de resource ID. Qualquer string funciona — adotado `/aws/<accountId>` e `/gcp/<projectId>`. Risco de alto para baixo.
- **R2 — reuso do schema FOCUS: confirmado como problema, e resolvido.** `focuscost_1.0.json` tem 96 mapeamentos explícitos, dos quais 52 (54%) são colunas `x_*` da Azure. Não é reutilizável. Solução: publicar `focuscost_1.0-aws.json` e `focuscost_1.0-gcp.json` e selecioná-los pelo campo `exportConfig.dataVersion` do manifest sintético (`1.0-aws` / `1.0-gcp`), já que o nome do schema é derivado de `type` + `dataVersion` — ambos sob nosso controle. **Zero alteração no ETL.**
- **Bônus:** o `additionalColumns` do arquivo de schema, hoje vazio, é o mecanismo pronto para carimbar `x_SourceProvider` e distinguir a origem dos dados no ADX.

Conclusão: a abordagem de manifest sintético está validada. Nenhum bloqueante restante para iniciar a implementação.

## Escopo proposto
### 1) Configuração de instalação
Adicionar parâmetros opcionais ao template principal e à UI do portal:
- `enableAwsFocusIngestion` (bool, default false)
- `enableGoogleFocusIngestion` (bool, default false)
- `awsFocusBucketName` / `awsFocusPrefix` / `awsFocusRegion`
- `awsFocusAccessKeySecretName` or `awsFocusCredentialsSecretName`
- `googleFocusBucketUri` / `googleFocusPrefix` / `googleProjectId`
- `googleFocusCredentialsSecretName`
- `focusIngestionSchedule` or `triggerFrequency`

Essas entradas devem ser condicionais: só ficam visíveis quando a fonte correspondente está habilitada.

### 2) Segurança e segredos
- Usar Key Vault para guardar credenciais de AWS/Google ao invés de expor secrets no template.
- Modelar a propriedade como refs do Key Vault, semelhante ao padrão de `remoteHubStorageKey`/`AzureKeyVaultSecret`.
- Validar que as credenciais sejam opcionais e que a configuração falhe de forma explícita quando o flag estiver habilitado mas o segredo ou a URI estiver faltando.

### 3) Extensão do Data Factory
Adicionar módulos Bicep no fluxo do hub para:
- criar `linkedService` de origem AWS e/ou Google
- criar datasets de origem e destino
- criar pipeline(s) de cópia para mover os arquivos FOCUS do storage externo para o `ingestion` do FinOps hub
- criar trigger periódico (daily/hourly, conforme a necessidade da fonte)
- preservar a lógica atual de `startTriggers` via `fx/hub-initialize.bicep`

A extensão deve seguir o mesmo padrão já usado em `Microsoft.FinOpsHubs/RemoteHub/app.bicep`.

### 4) Ingestão e normalização
- Garantir que o destino final seja compatível com o modelo já usado pelo hub para arquivos FOCUS/Parquet e ingestão analítica.
- Definir regras de estrutura de pastas e nomenclatura para evitar colisão entre fontes AWS, Google e Azure.
- Validar se o schema de FOCUS do provedor é consistente com o esperado pelo hub e se será necessária uma camada de transformação antes da ingestão final.

### 5) Testes, validação e documentação
- Validar o deploy do template com flags desligadas (baseline intacta).
- Validar o deploy com cada origem habilitada separadamente.
- Validar `bicep build`/deployment validation e testes do repositório (`src/scripts/Test-PowerShell`).
- Atualizar documentação do FinOps hub e do portal de deployment para explicar o fluxo opcional multi-cloud.

## Riscos e considerations
- A topologia de integração AWS/Google tende a depender de serviços, APIs e credenciais específicas; a solução deve ser um “connector pattern”, não um hardcoded scenario único.
- O custo e a latência de ingestão aumentam com conexões externas; o recurso deve ser explicitamente opcional e documentado.
- O hub tem a premissa de dados Azure-first; a extensão multicloud deve ser isolada para não afetar a instalação padrão.
- As configurações Google/AWS podem exigir regras de rede e acesso de saída distintas; esse ponto precisa ser avaliado no design do template.

## Tarefas planejadas
- `multicloud-research`: confirmar o escopo técnico e escolher o modelo de extensão mais compatível com o hub atual.
- `multicloud-design`: definir parâmetros, UI e objeto de configuração do instalador.
- `multicloud-iac`: especificar o Bicep do hub e o pattern do Data Factory para AWS/Google.
- `multicloud-docs`: validar documentação, testes e rollout.

## Resultado esperado
Uma instalação do FinOps hub que continue funcionando como Azure-first por default, mas permita a opção de coletar dados FOCUS do AWS e Google como fontes complementares, com segurança, isolamento e compatibilidade com o fluxo atual do hub.
