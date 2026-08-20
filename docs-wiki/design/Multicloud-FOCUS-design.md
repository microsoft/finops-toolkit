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
| `exportConfig.dataVersion` | 2ª parte do nome do schema **e** `x_SourceType` / `x_SourceVersion` | `1.0-aws` / `1.0-gcp` (ver §2.1) |
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

Consequência: publicar `focuscost_1.0-aws.json` e definir `dataVersion: '1.0-aws'` faz o ETL carregar o schema correto **sem uma única alteração no pipeline existente**.

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
| 6 | `.../Microsoft.CostManagement/Exports/schemas/focuscost_1.0-aws.json` | novo (ver R2) |
| 7 | `.../Microsoft.CostManagement/Exports/schemas/focuscost_1.0-gcp.json` | novo (ver R2) |
| 8 | `.../Microsoft.CostManagement/Exports/app.bicep` | + 2 entradas no map `files:` do módulo de schemas (linhas 59-85) |
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

**R2 — paridade de schema FOCUS — RESOLVIDO, exige schemas por provedor.** Spike executado. `focuscost_1.0.json` é um `TabularTranslator` com **96 mapeamentos explícitos, dos quais 52 (54%) são colunas `x_*` específicas da Azure** (`x_AccountId`, `x_BillingProfileId`, `x_BillingExchangeRate`, …) e apenas 44 são FOCUS-padrão. Um export FOCUS de AWS/GCP não tem essas 52 colunas, e um mapeamento explícito sobre colunas de origem inexistentes falha.

Portanto **não se reusa o schema existente**. Publicar arquivos próprios no mesmo `files: {}` do `hub-storage.bicep` usado em `Exports/app.bicep:59-85`:

| Arquivo | Conteúdo |
| --- | --- |
| `schemas/focuscost_1.0-aws.json` | 44 mapeamentos FOCUS-padrão + colunas `x_` da AWS + `additionalColumns: [{ name: 'x_SourceProvider', value: 'AWS' }]` |
| `schemas/focuscost_1.0-gcp.json` | idem, com `value: 'Google Cloud'` |

O `additionalColumns` do arquivo de schema é injetado na cópia (`activity('Load Schema Mappings').output.firstRow.additionalColumns`) e está **vazio** nos schemas atuais — é o mecanismo limpo para carimbar a proveniência sem tocar no pipeline.

Residual: o ETL também injeta `x_SourceType` e `x_SourceVersion` a partir de `dataVersion`, então esses campos ficarão com `1.0-aws` / `1.0-gcp`. Bom para rastreabilidade; confirmar apenas que a ingestão do ADX roteia tabelas por pasta/dataset e não por `x_SourceVersion`.

**R3 — rede privada (médio).** Com `enablePublicAccess = false`, a saída para S3/GCS depende do Managed VNet do ADF e do NAT Gateway (`enableNatGateway`). Documentar que a combinação rede privada + multicloud exige `enableNatGateway = true`.

**R4 — segredos de longa duração (médio).** Access keys de AWS/GCS não expiram sozinhas. O secret já nasce no Key Vault, mas o README deve exigir rotação e uma policy IAM mínima (`s3:GetObject` + `s3:ListBucket` restrito ao prefixo).

**R5 — custo de egresso (baixo).** A transferência sai do provedor de origem e é cobrada por ele. Documentar junto com a estimativa de custo, como o README de Invoices já faz.

---

## 8b. Resultado do spike

Executado em `arthursilvany/multicloud-focus`, por leitura estática de `Microsoft.CostManagement/Exports/app.bicep` e dos arquivos de schema.

| Item | Hipótese inicial | Resultado |
| --- | --- | --- |
| R1 — parsing do `resourceId` | Alto risco; poderia invalidar a abordagem | **Refutado.** É só um segmento de caminho. Formato livre. |
| R2 — reuso do `focuscost_1.0.json` | Provavelmente reutilizável | **Refutado.** 52/96 colunas são Azure-específicas. Precisa de schema por provedor. |
| Seleção do schema | Fixa no ETL | **Melhor que o esperado.** Derivada de `type` + `dataVersion`, ambos controlados pelo manifest. Extensão sem tocar no pipeline. |
| Proveniência multicloud | Precisaria de coluna nova no ETL | **Já existe.** `additionalColumns` do schema, hoje vazio. |

Conclusão: a abordagem de manifest sintético está validada. O trabalho de implementação concentra-se em dois arquivos de schema e dois apps Bicep — nenhuma alteração no ETL existente.

Pendência remanescente antes do merge: validar os dois schemas contra um arquivo FOCUS real de cada provedor (as 44 colunas padrão e os nomes `x_` de cada um).

---

## 9. Ordem de execução

1. ~~Spike do R1 e R2~~ — **concluído**, ver §8b.
2. Escrever `focuscost_1.0-aws.json` e validar contra um arquivo FOCUS real da AWS.
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
