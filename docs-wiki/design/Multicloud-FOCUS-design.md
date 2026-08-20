# Design: ingestão opcional de FOCUS AWS e Google no FinOps hub

> Detalhamento técnico do plano aprovado em [Multicloud-FOCUS-plan](./Multicloud-FOCUS-plan.md). Baseado na leitura do código atual em `src/templates/finops-hub`.
> Branch de trabalho: `arthursilvany/multicloud-focus`.

---

## 1. Descoberta que define a arquitetura

O hub **já tem** todo o pipeline de FOCUS → Parquet → ADX. O que falta é apenas **entregar o arquivo na porta certa**.

Cadeia atual, confirmada no código:

```
Cost Management export
  → grava arquivos + manifest.json no container "msexports"
    → trigger msexports_ManifestAdded  (BlobEventsTrigger, storagePathEndsWith: 'manifest.json')
      → pipeline msexports_ExecuteETL   (lê o manifest, escolhe o schema)
        → msexports_ETL_ingestion       (converte para Parquet no container "ingestion")
          → trigger ingestion_ManifestAdded
            → pipeline de ingestão do ADX / Fabric
```

Evidências:

| Fato | Arquivo |
| --- | --- |
| Trigger dispara **só** em `manifest.json` | `Microsoft.CostManagement/Exports/app.bicep:1712-1728` |
| Trigger de ingestão idem | `Microsoft.FinOpsHubs/Analytics/app.bicep:682-698` |
| Schemas FOCUS 1.0 / 1.0r2 / 1.2 já publicados no container `config` | `Microsoft.CostManagement/Exports/app.bicep:59-85` |
| Datasets para CSV, **gzip** e **Parquet** já existem | `Microsoft.CostManagement/Exports/app.bicep:164-254` |

**Consequência de design:** não construir um ETL paralelo. O conector AWS/Google deve apenas:

1. copiar os arquivos FOCUS do bucket para `msexports/<provider>/...`;
2. gravar um `manifest.json` compatível **por último**.

A partir daí, tudo o que já existe funciona sem alteração — incluindo a conversão para Parquet, a retenção e a ingestão no ADX. Como o trigger só reage a `manifest.json`, gravar os dados antes e o manifest depois é seguro por construção.

Isso também resolve o formato: AWS entrega FOCUS em `.csv.gz` ou `.parquet` e o GCS em `.csv`/`.parquet` — os três já são tratados pelos datasets `msexports`, `msexports_gzip` e `msexports_parquet`.

---

## 2. Contrato do `manifest.json`

Campos efetivamente consumidos pelo `msexports_ExecuteETL` (extraídos das expressões `activity('Read Manifest').output.firstRow.*`):

| Campo | Uso | Valor para AWS/GCP |
| --- | --- | --- |
| `exportConfig.type` | 1ª parte do nome do schema | `FocusCost` |
| `exportConfig.dataVersion` | 2ª parte do nome do schema (e **só** isso — ver §8/R2) | `1.2-aws` / `1.2-gcp` (ver §2.1) |
| `exportConfig.exportName` | nome lógico do export | `aws-focus` / `gcp-focus` |
| `exportConfig.resourceId` | deriva o scope (= segmento de caminho) | ver §2.2 |
| `runInfo.runId` | identidade da execução | GUID gerado no pipeline |
| `runInfo.startDate` | período dos dados | início do mês do arquivo |
| `blobCount` / `blobs[].blobName` | lista de arquivos | preenchido pelo Get Metadata |
| `dataRowCount` | short-circuit de export vazio | omitir ou `null` |
| `retention.msexports.days` | limpeza | copiar do `settings.json` |
| `additionalColumns`, `translator` | vêm do arquivo de schema, não do manifest | omitir |

O manifest é montado no próprio pipeline (atividade `Set Variable` + `Copy` com `JsonSink`), não como arquivo estático — o conteúdo depende do run.

### 2.1 Como o schema é selecionado — o ponto de extensão

```
schemaFile = toLower(concat(exportDatasetType, '_', exportDatasetVersion, <sufixo de canal>, '.json'))
```

O `<sufixo de canal>` (`_ea` / `_mca`) só é aplicado quando `mcaColumnToCheck` não é nulo, e essa variável é nula para `FocusCost` — ela só é preenchida para `pricesheet`, `reservationtransactions` e `reservationrecommendations`. Portanto, para FOCUS o nome do arquivo é determinado **inteiramente** por dois campos que nós controlamos no manifest sintético.

Consequência: publicar `focuscost_1.2-aws.json` e definir `dataVersion: '1.2-aws'` faz o ETL carregar o schema correto **sem uma única alteração no pipeline existente**. `exportConfig.type`, ao contrário, é obrigatoriamente `FocusCost` — ver §8d.

### 2.2 Valor de `exportConfig.resourceId`

Recomendado: `/aws/<accountId>` e `/gcp/<projectId>`.

Produz os caminhos `FocusCost/2026/08/aws/123456789012/` e `FocusCost/2026/08/gcp/meu-projeto/`, legíveis e isolados dos caminhos de scope da Azure. Ver §8/R1 para a análise que sustenta essa liberdade de formato.

---

## 3. Parâmetros novos

### `main.bicep` e `modules/hub.bicep`

Seguem exatamente o padrão de `enableInvoiceDownload` (`main.bicep:52-57`).

```bicep
@description('Optional. Enable ingestion of FOCUS cost data exported from Amazon Web Services. Requires an S3 bucket with a FOCUS 1.0 or 1.2 export and an access key stored during deployment. Default: false.')
param enableAwsFocusIngestion bool = false

@description('Optional. Name of the Amazon S3 bucket that contains the FOCUS export. Requires enableAwsFocusIngestion.')
param awsBucketName string = ''

@description('Optional. Path prefix within the S3 bucket where FOCUS files are written. Requires enableAwsFocusIngestion.')
param awsBucketPrefix string = ''

@description('Optional. AWS region of the S3 bucket. Requires enableAwsFocusIngestion.')
param awsRegion string = ''

@description('Optional. AWS access key ID used to read the S3 bucket. Requires enableAwsFocusIngestion.')
param awsAccessKeyId string = ''

@description('Optional. AWS secret access key used to read the S3 bucket. Stored in Key Vault. Requires enableAwsFocusIngestion.')
@secure()
param awsSecretAccessKey string = ''

@description('Optional. FOCUS version of the AWS export. Allowed: 1.0, 1.2. Default: 1.0.')
@allowed(['1.0', '1.2'])
param awsFocusVersion string = '1.0'
```

Equivalente para Google, com nomes `enableGoogleFocusIngestion`, `googleBucketName`, `googleBucketPrefix`, `googleProjectId`, `googleAccessKeyId`, `googleSecretAccessKey` (HMAC do GCS), `googleFocusVersion`.

Comuns aos dois:

```bicep
@description('Optional. Hour of the day (UTC) to collect multicloud FOCUS files. Default: 4.')
@minValue(0)
@maxValue(23)
param multiCloudScheduleHour int = 4
```

**Chave do design:** os defaults deixam tudo desligado. Um deploy existente que rode `main.bicep` sem esses parâmetros não muda em nada — nenhum recurso novo, nenhum custo novo.

### Telemetria — `modules/hub.bicep`

O `telemetryString` (`hub.bicep:206-222`) é limitado a 12 caracteres. Acrescentar apenas dois flags:

```bicep
// A = AWS FOCUS ingestion, G = Google FOCUS ingestion
enableAwsFocusIngestion ? 'A' : ''
enableGoogleFocusIngestion ? 'G' : ''
```

---

## 4. UI do portal — `createUiDefinition.json`

Estrutura atual dos steps: `pricing`, `retention`, `recommendations`, `invoices`, `advanced`, `tags`.

Adicionar um step `multicloud` entre `invoices` e `advanced`, espelhando o layout do step `invoices` (`createUiDefinition.json:841-930`):

```
- multicloud  (label: "🆕 Multicloud")
    * multicloudIntro        [Microsoft.Common.TextBlock]
    * enableAws              [Microsoft.Common.CheckBox]
    * aws                    [Microsoft.Common.Section]   visible: [steps('multicloud').enableAws]
        - bucketName         [Microsoft.Common.TextBox]
        - bucketPrefix       [Microsoft.Common.TextBox]
        - region             [Microsoft.Common.TextBox]
        - accessKeyId        [Microsoft.Common.TextBox]
        - secretAccessKey    [Microsoft.Common.PasswordBox]
        - focusVersion       [Microsoft.Common.DropDown]  (1.0 | 1.2)
    * enableGoogle           [Microsoft.Common.CheckBox]
    * google                 [Microsoft.Common.Section]   visible: [steps('multicloud').enableGoogle]
        - (mesmos campos + projectId)
    * schedule               [Microsoft.Common.Section]
    * permissions            [Microsoft.Common.Section]   (texto sobre a política IAM mínima)
```

Outputs, no mesmo estilo dos existentes (`createUiDefinition.json:1102`):

```json
"enableAwsFocusIngestion": "[steps('multicloud').enableAws]",
"awsBucketName": "[if(steps('multicloud').enableAws, steps('multicloud').aws.bucketName, '')]",
"awsSecretAccessKey": "[if(steps('multicloud').enableAws, steps('multicloud').aws.secretAccessKey, '')]"
```

O `if(...)` é obrigatório: garante que campos ocultos nunca vazem valores residuais para o template — mesmo padrão já usado em `remoteHubStorageUri`/`remoteHubStorageKey`.

Usar `Microsoft.Common.PasswordBox` para os segredos, para que não apareçam em tela nem no histórico do portal.

---

## 5. Módulos novos

Dois apps irmãos, seguindo a estrutura de `Microsoft.Billing/Invoices` (o app opcional mais recente e completo do repo):

```
modules/Microsoft.FinOpsHubs/AmazonWebServices/
    app.bicep
    metadata.bicep
    README.md
modules/Microsoft.FinOpsHubs/GoogleCloud/
    app.bicep
    metadata.bicep
    README.md
```

Publisher = `Microsoft.FinOpsHubs`, porque quem publica o conector é a Microsoft. Isso mantém os recursos no Data Factory / Key Vault / storage do próprio hub em vez de criar um segundo Data Factory quando `publisherIsolation` for ativado no futuro (`hub-types.bicep`, `newApp`).

### Cabeçalho do `app.bicep` (padrão obrigatório do repo)

```bicep
import { finOpsToolkitVersion, HubAppProperties, privateRoutingForLinkedServices, isSupportedVersion } from '../../fx/hub-types.bicep'
import { AppMetadata as CoreMetadata } from '../Core/metadata.bicep'
import { AppMetadata as ExportsMetadata } from '../../Microsoft.CostManagement/Exports/metadata.bicep'

metadata hubApp = {
  id: 'Microsoft.FinOpsHubs.AmazonWebServices'
  version: '$$ftkver$$'
  dependencies: ['Microsoft.FinOpsHubs.Core', 'Microsoft.CostManagement.Exports']
}

@validate(x => isSupportedVersion(x.version, '13.0', ''), 'AWS FOCUS ingestion requires FinOps hubs version 13.0 or higher.')
param core CoreMetadata
```

A dependência de `Microsoft.CostManagement.Exports` é real e não opcional: é dele que vêm o container `msexports` e os arquivos de schema.

### Recursos criados por app

| Tipo | Nome (AWS) | Nome (Google) | Função |
| --- | --- | --- | --- |
| Key Vault secret | `aws-secret-access-key` | `gcp-secret-access-key` | via `fx/hub-vault.bicep` |
| Linked service | `aws_s3` | `gcp_storage` | `AmazonS3` / `GoogleCloudStorage` |
| Dataset | `aws_focus_source` | `gcp_focus_source` | `Binary` + `AmazonS3Location` / `GoogleCloudStorageLocation` |
| Dataset | `aws_focus_landing` | `gcp_focus_landing` | `Binary` no container `msexports` |
| Dataset | `aws_focus_manifest` | `gcp_focus_manifest` | `Json` no container `msexports` |
| Pipeline | `aws_CollectFocusExport` | `gcp_CollectFocusExport` | copiar + gerar manifest |
| Trigger | `aws_DailySchedule` | `gcp_DailySchedule` | `ScheduleTrigger` diário |

O linked service usa segredo do Key Vault exatamente como o RemoteHub (`Microsoft.FinOpsHubs/RemoteHub/app.bicep:88-98`):

```bicep
resource linkedService_awsS3 'linkedservices' = {
  name: 'aws_s3'
  properties: {
    type: 'AmazonS3'
    typeProperties: {
      authenticationType: 'AccessKey'
      accessKeyId: awsAccessKeyId
      secretAccessKey: {
        type: 'AzureKeyVaultSecret'
        store: { referenceName: app.keyVault, type: 'LinkedServiceReference' }
        secretName: awsSecretSecretName
      }
    }
    ...privateRoutingForLinkedServices(app.hub)
  }
}
```

O spread `...privateRoutingForLinkedServices(app.hub)` não é opcional — sem ele o linked service ignora o Managed VNet quando o hub roda em rede privada.

### Atividades do pipeline `*_CollectFocusExport`

1. **Load Settings** — `Lookup` no dataset `config` para ler `retention.msexports.days`.
2. **Set Run Id** — `@guid()`.
3. **List Source Files** — `Get Metadata` (`childItems`) no prefixo do bucket.
4. **Filter New Files** — `Filter` pelo mês corrente / arquivos ainda não copiados.
5. **Copy FOCUS Files** — `ForEach` (sequencial = false) com `Copy` binário de S3/GCS → `msexports/<provider>/<periodo>/<runId>/`.
6. **Build Manifest** — `Set Variable` montando o JSON do contrato da seção 2.
7. **Write Manifest** — `Copy` com `JsonSink` gravando `manifest.json` na **mesma pasta**, com `dependsOn: Succeeded` do passo 5.

O passo 7 depender de `Succeeded` (não `Completed`) é o que garante que o manifest nunca seja publicado sobre uma cópia parcial.

### Estrutura de pastas no `msexports`

```
msexports/
├── aws/<accountId>/<YYYYMMDD-YYYYMMDD>/<runId>/{data files, manifest.json}
└── gcp/<projectId>/<YYYYMMDD-YYYYMMDD>/<runId>/{data files, manifest.json}
```

Prefixos `aws/` e `gcp/` isolam as fontes e evitam colisão com os caminhos de scope do Cost Management.

---

## 6. Ligação em `modules/hub.bicep`

Inserir depois do bloco de Invoices (`hub.bicep:368-380`), seguindo o mesmo formato:

```bicep
//------------------------------------------------------------------------------
// Multicloud FOCUS ingestion
//------------------------------------------------------------------------------

module awsFocus 'Microsoft.FinOpsHubs/AmazonWebServices/app.bicep' = if (enableAwsFocusIngestion) {
  name: 'Microsoft.FinOpsHubs.AmazonWebServices'
  params: {
    app: newApp(hub, 'Microsoft.FinOpsHubs', 'AmazonWebServices')
    core: core.outputs.metadata
    exports: cmExports.outputs.metadata
    bucketName: awsBucketName
    // ...
  }
}
```

E acrescentar `awsFocus` / `googleFocus` ao `dependsOn` do módulo `startTriggers` (`hub.bicep:405-420`) — caso contrário os triggers novos ficam parados após o deploy, porque quem os inicia é o `Init-DataFactory.ps1` chamado por `fx/hub-initialize.bicep`.

---

## 7. Checklist de arquivos

| # | Arquivo | Ação |
| --- | --- | --- |
| 1 | `src/templates/finops-hub/main.bicep` | + parâmetros, + passthrough |
| 2 | `src/templates/finops-hub/modules/hub.bicep` | + parâmetros, + 2 módulos, + telemetria, + `dependsOn` |
| 3 | `src/templates/finops-hub/createUiDefinition.json` | + step `multicloud`, + outputs |
| 4 | `.../modules/Microsoft.FinOpsHubs/AmazonWebServices/{app,metadata}.bicep` + `README.md` | novo |
| 5 | `.../modules/Microsoft.FinOpsHubs/GoogleCloud/{app,metadata}.bicep` + `README.md` | novo |
| 6 | `.../Microsoft.CostManagement/Exports/schemas/focuscost_1.2-aws.json` | ✅ **criado** — 56 mapeamentos, ver R2 |
| 7 | `.../Microsoft.CostManagement/Exports/schemas/focuscost_1.2-gcp.json` | novo (ver R2) |
| 8 | `.../Microsoft.CostManagement/Exports/app.bicep` | ✅ **feito** — schema AWS registrado no map `files:` |
| 9 | `src/templates/finops-hub/.build.config` | + 2 READMEs em `ignore` |
| 10 | `docs-mslearn/toolkit/hubs/template.md` | + linhas na tabela de parâmetros |
| 11 | `docs-mslearn/toolkit/hubs/configure-multicloud.md` | novo how-to |
| 12 | `docs-mslearn/toolkit/changelog.md` | entrada **Added** em FinOps hubs |
| 13 | `src/powershell/Public/Deploy-FinOpsHub.ps1` | + parâmetros equivalentes |
| 14 | `src/powershell/Tests/Unit/Deploy-FinOpsHub.Tests.ps1` | + casos |

Os itens 9, 10 e 12 são exigências do repositório, não opcionais: o `.build.config` precisa ignorar READMEs de módulo (senão vão para o pacote do Azure Quickstart Templates), e o changelog tem regras próprias em `docs-wiki/Coding-guidelines.md`.

Nota sobre o item 8: os schemas ficam no app `Microsoft.CostManagement.Exports` porque é ele que possui o container `msexports` e publica a pasta `schemas/`. Alternativa, se preferir isolamento: cada app multicloud publica o próprio schema via `fx/hub-storage.bicep` no mesmo caminho — evita tocar no app de Exports, ao custo de espalhar a responsabilidade.

---

## 8. Riscos

**R1 — `exportConfig.resourceId` — RESOLVIDO, risco baixo.** Spike executado. Expressão real:

```
scope = split(toLower(exportConfig.resourceId), '/providers/microsoft.costmanagement/exports/')[0]
destino = replace(concat(hubDataset, '/', ano, '/', mês, '/', toLower(scope), ...), '//', '/')
```

`split()` com delimitador ausente devolve a string inteira em `[0]`. Não há decomposição de resource ID, validação de formato nem lookup — o valor é usado apenas como segmento de caminho, em minúsculas, com `//` colapsado. Qualquer string funciona. A hipótese original de que um ARN quebraria o parsing estava errada. Não é necessário pseudo-scope no formato Azure; ver §2.2.

**R2 — paridade de schema FOCUS — RESOLVIDO, exige schemas por provedor.** Validado contra um arquivo FOCUS **real** da AWS (parquet snappy, 60 colunas, 19.827 linhas). O arquivo é **FOCUS 1.2**, não 1.0.

Comparação com `focuscost_1.2.json` (104 mapeamentos):

| | Qtd | Observação |
| --- | --- | --- |
| Colunas FOCUS que batem exatamente por nome | 53 | reusáveis sem alteração |
| Colunas `x_*` da Azure ausentes no arquivo AWS | 51 | `x_BillingProfileId`, `x_SkuMeterId`, … — não podem ser mapeadas |
| Colunas da AWS ausentes no schema do hub | 7 | `AvailabilityZone`, `x_Operation`, `x_ServiceCode`, `x_Discounts`, 3× `PricingCurrency*` |

Portanto **não se reusa o schema existente**. Publicado `schemas/focuscost_1.2-aws.json` com **56 mapeamentos**: os 53 compartilhados (tipos herdados do schema 1.2 do hub) + `AvailabilityZone` + `x_Operation` + `x_ServiceCode` — as três confirmadas como colunas existentes da tabela `Costs_raw` do ADX.

Omitidas por não existirem no schema do ADX: `x_Discounts` (`map<string,double>`) e `PricingCurrencyContractedUnitPrice` / `PricingCurrencyEffectiveCost` / `PricingCurrencyListUnitPrice`. Incluí-las exigiria alterar `IngestionSetup_RawTables.kql`, `HubSetup_v1_2.kql` e as tabelas finais — mudança que afeta também os dados da Azure e fica fora do escopo desta feature. Registrar como gap conhecido no README.

**Correção de um erro do design anterior:** as `additionalColumns` do arquivo de schema **não** servem para carimbar a proveniência. O ETL aplica

```
intersection(
  [{"name":"x_SourceProvider","value":"Microsoft"}, {"name":"x_SourceName","value":"Cost Management"},
   {"name":"x_SourceType","value":"<dataVersion>"}, {"name":"x_SourceVersion","value":"<dataVersion>"}],
  activity('Load Schema Mappings').output.firstRow.additionalColumns
)
```

(`Exports/app.bicep:1225`). Como é uma **interseção** com um array de valores fixos em `Microsoft` / `Cost Management`, um objeto com `"value":"AWS"` nunca sobrevive. E como **todos** os 14 arquivos de schema do repositório têm `additionalColumns: []`, a interseção é sempre vazia hoje — o ETL não carimba `x_Source*` para nenhum dataset.

**Consequência boa:** `dataVersion` não vaza para `x_SourceType` / `x_SourceVersion`. É um parâmetro puramente de seleção de schema, sem efeito colateral. O risco residual apontado antes **não existe**.

**R3 — rede privada (médio).** Com `enablePublicAccess = false`, a saída para S3/GCS depende do Managed VNet do ADF e do NAT Gateway (`enableNatGateway`). Documentar que a combinação rede privada + multicloud exige `enableNatGateway = true`.

**R4 — segredos de longa duração (médio).** Access keys de AWS/GCS não expiram sozinhas. O secret já nasce no Key Vault, mas o README deve exigir rotação e uma policy IAM mínima (`s3:GetObject` + `s3:ListBucket` restrito ao prefixo).

**R5 — custo de egresso (baixo).** A transferência sai do provedor de origem e é cobrada por ele. Documentar junto com a estimativa de custo, como o README de Invoices já faz.

---

## 8b. Resultado do spike

Executado em `arthursilvany/multicloud-focus`, por leitura estática do ETL e dos schemas, e validado contra um export FOCUS **real** da AWS.

| Item | Hipótese inicial | Resultado |
| --- | --- | --- |
| R1 — parsing do `resourceId` | Alto risco; poderia invalidar a abordagem | **Refutado.** É só um segmento de caminho. Formato livre. |
| R2 — reuso do `focuscost_1.2.json` | Provavelmente reutilizável | **Refutado.** 51 das 104 colunas são Azure-específicas. Precisa de schema por provedor. |
| Seleção do schema | Fixa no ETL | **Melhor que o esperado.** Derivada de `type` + `dataVersion`, e `dataVersion` é livre e sem efeito colateral. |
| Proveniência via `additionalColumns` | Mecanismo pronto | **Refutado.** O `intersection()` com valores fixos `Microsoft` bloqueia. Ver R2. |
| Proveniência multicloud | Precisaria de coluna nova | **Já resolvido a montante.** Ver §8c. |

### 8c. O ADX já tem suporte a AWS e GCP

Achado que reduz o escopo da feature. `IngestionSetup_v1_0.kql:367-372` já classifica o provedor a partir da forma dos dados:

```kusto
| extend ProviderName = case(
    isnotempty(ProviderName), ProviderName,
    isnotempty(coalesce(x_CostCategories, x_Discount, x_Operation, x_ServiceCode, x_UsageType)), 'AWS',
    isnotempty(coalesce(tostring(UsageAmount), tostring(x_Cost), ..., x_Project, x_ServiceId)), 'GCP',
    isnotempty(coalesce(x_BillingProfileId, x_InvoiceSectionId)), 'Microsoft',
    ''
)
| extend x_SourceProvider = coalesce(x_SourceProvider, ProviderName)
| extend x_SourceVersion  = coalesce(x_SourceVersion, case(...))
```

A tabela `Costs_raw` já declara `x_Operation` e `x_ServiceCode` com o comentário `// AWS 1.0`, e `AvailabilityZone` como `// FOCUS 0.5+`. O arquivo real da AWS traz `ProviderName = 'AWS'` preenchido, então a classificação acerta pelo primeiro branch.

**Conclusão: nenhum trabalho de proveniência é necessário.** Basta entregar os dados em `Costs_raw` que o ADX classifica, versiona e roteia sozinho.

### 8d. Restrições fixadas pelo roteamento de tabela

`Analytics/app.bicep:1815` define a tabela de destino como o **primeiro segmento da pasta** de ingestão:

```
table = concat(first(split(containerFolderPath, '/')), '_raw')
```

e `Exports/app.bicep:847` mapeia `exportDatasetType = 'focuscost'` → `hubDataset = 'Costs'`, com fallback para o próprio nome do tipo. Logo:

| Campo do manifest | Valor obrigatório | Motivo |
| --- | --- | --- |
| `exportConfig.type` | **`FocusCost`** (exato) | qualquer outro valor gera a pasta `<tipo>` e a tabela `<tipo>_raw`, que não existe |
| `exportConfig.dataVersion` | livre | só seleciona o arquivo de schema |

O uso de sufixo em `dataVersion` já tem precedente no repositório: `focuscost_1.0-preview(v1).json` e `focuscost_1.2-preview.json`.

---

---

## 9. Ordem de execução

1. ~~Spike do R1 e R2~~ — **concluído**, ver §8b.
2. ~~Escrever `focuscost_1.2-aws.json` e validar contra um arquivo FOCUS real da AWS~~ — **concluído**.
3. App AWS completo (Bicep + README).
4. App Google, reaproveitando o formato validado.
5. UI, parâmetros do PowerShell e testes.
6. Documentação e changelog.

Validação a cada etapa:

```powershell
az bicep build --file src/templates/finops-hub/main.bicep --stdout
./src/scripts/Build-Toolkit finops-hub
./src/scripts/Deploy-Toolkit finops-hub -Build -WhatIf
./src/scripts/Test-PowerShell -Lint -Hubs
```

O primeiro teste de regressão obrigatório é um deploy **com as duas flags desligadas**, comparando o `what-if` com o baseline: o resultado tem que ser vazio.
