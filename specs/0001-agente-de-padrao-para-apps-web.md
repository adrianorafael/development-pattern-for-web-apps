# Spec. Development Pattern for Web Apps (a própria skill)

> A regra R3 exige especificação antes do código. Ela vale também para esta skill.
> Este documento é a spec que a originou, mantida como registro do desenho, e como
> exemplo trabalhado do formato que `assets/templates/spec.template.md` define.

| | |
| --- | --- |
| **Spec** | `0001-agente-de-padrao-para-apps-web` |
| **Status** | 🔵 implementada |
| **Data** | 2026-09-05 |
| **Versão alvo** | 1.0.0 |
| **Trilha** | conteúdo (Markdown, templates, shell), não é uma aplicação |

---

## 1. Objetivo

Um agente de IA passa a construir os aplicativos web pessoais do autor. PHP+MySQL na
Hostinger e Next.js+Tailwind na Vercel, sem que ele precise, a cada sessão, relembrar as
mesmas exigências de segurança, instalação, atualização e teste.

## 2. Fora de escopo

- Outros stacks (Laravel, WordPress, Python, mobile).
- Outras hospedagens além de Hostinger e Vercel.
- Executar os testes: a skill **gera** o roteiro; quem executa é o Claude Cowork ou o autor.
- Substituir revisão humana. A skill reduz a chance de erro; não elimina a leitura do diff.

## 3. Requisitos funcionais

| # | Requisito |
| --- | --- |
| RF-001 | A skill carrega sozinha ao primeiro prompt sobre um app web nas duas trilhas. |
| RF-002 | Impede SQL montado por concatenação, com regra, referência dedicada e scanner. |
| RF-003 | Impede que credenciais de banco e chaves de API cheguem ao repositório. |
| RF-004 | Faz todo repositório novo nascer privado, e exige varredura do histórico para publicar. |
| RF-005 | Exige especificação com requisitos numerados e casos de teste antes do código. |
| RF-006 | Aplica segurança proporcional ao porte, sobre um piso que nenhum projeto dispensa. |
| RF-007 | Gera, em toda entrega, um roteiro de testes em Markdown executável pelo Claude Cowork. |
| RF-008 | Exige Wizard de instalação em todo app PHP+MySQL, capaz de criar ou recriar o banco. |
| RF-009 | Exige painel administrativo que instala pacotes ZIP com arquivos e migrações SQL. |
| RF-010 | Impõe interface por componentes nas duas trilhas. |
| RF-011 | Mantém versão, CHANGELOG, README e versão do schema em sincronia. |
| RF-012 | Exige alvo nomeado, backup e caminho de rollback antes de qualquer deploy. |
| RF-013 | Faz os apps expor URLs como rotas semânticas, nunca caminhos de arquivo. |
| RF-014 | Publica uma página do projeto em Tailwind, com modo claro padrão e escuro opcional. |
| RF-015 | Conecta-se à conta Vercel do autor para diagnosticar e corrigir build quebrado, em ciclo com teto. |
| RF-016 | Faz o texto de interface seguir as convenções do domínio, sem travessão e com corpo justificado. |

## 4. Requisitos não funcionais

- Formato aberto [Agent Skills](https://agentskills.io): funciona em Claude Code, Cursor,
  Copilot, OpenCode e outros.
- `SKILL.md` legível de ponta a ponta em poucos minutos; profundidade nas referências,
  carregadas sob demanda.
- Nenhuma documentação de terceiros vendorizada: php.net, nextjs.org, tailwindcss.com e
  OWASP são referenciados por URL e lidos na sessão.
- Português (pt-BR) em todo o conteúdo.

## 5. Modelo de conteúdo

```
SKILL.md            17 regras · 8 fases · 3 portões · roteamento de referências
references/         17 documentos, um por área de risco
assets/templates/   19 arquivos copiáveis
assets/scripts/     3 scanners executáveis
docs/               página do projeto (Tailwind compilado, claro/escuro)
```

Cada regra `Rn` tem exatamente uma referência responsável por ela. Cada referência abre
declarando qual regra impõe.

## 6. Regras de negócio

- Uma regra que não pode ser cumprida faz o agente **parar e dizer**, nunca entregar uma
  versão degradada em silêncio.
- Os três portões (spec, push, deploy) são paradas duras.
- O meio do trabalho é livre: a skill segura invariantes, não policia cada edição.
- Todo exemplo inseguro é rotulado com ❌ e acompanhado da forma correta com ✅.

## 7. Segurança

O risco desta skill é **ensinar errado**. Um trecho vulnerável sem rótulo será copiado para
um projeto real. Mitigações:

- Todo exemplo perigoso vem marcado e emparelhado com a versão correta.
- Os scanners são testados contra fixtures bons e ruins antes de cada publicação.
- Os placeholders são obviamente falsos, para não serem confundidos com valores reais.
- A skill declara explicitamente que varredura limpa é necessária, não suficiente.

## 8. Critérios de aceite

```
RF-002
  DADO um arquivo PHP com "SELECT * FROM t WHERE id = " . $_GET['id']
  QUANDO scan-sql-injection.sh roda sobre ele
  ENTÃO ele reporta achado de severidade ALTA e sai com código 1

  DADO um arquivo PHP que usa prepare/execute e resolve ORDER BY por allowlist
    com o marcador scan-sql:allow
  QUANDO o mesmo scanner roda
  ENTÃO ele sai limpo, com código 0

RF-003
  DADO um arquivo com 'password' => 'ValorRealQualquer'   # scan-secrets:allow (é o exemplo)
  QUANDO scan-secrets.sh roda
  ENTÃO ele reporta achado de severidade ALTA

  DADO os 18 templates deste repositório
  QUANDO scan-secrets.sh roda sobre eles
  ENTÃO ele sai limpo: todos os placeholders são reconhecidos como tais

RF-007
  DADO um app entregue
  QUANDO a Fase 5 conclui
  ENTÃO existe qa/roteiro-de-testes.md com as seis suítes, a matriz de rastreabilidade,
    e os requisitos sem cobertura declarados por nome
```

## 9. Casos de teste

| Caso | Cobre | Verificação |
| --- | --- | --- |
| CT-001 | RF-002 | Fixture ruim (PHP e TS) → 11 achados |
| CT-002 | RF-002 | Fixture bom (PHP e TS) → limpo |
| CT-003 | RF-003 | Fixture com credencial → achado ALTA |
| CT-004 | RF-003 | Os 18 templates → limpo |
| CT-005 | RF-008 | `php -l install-wizard.php.template` → sem erro de sintaxe |
| CT-006 | RF-009 | `php -l updater.php.template` → sem erro de sintaxe |
| CT-007 | não se aplica | `manifest.json.template` é JSON válido |
| CT-008 | não se aplica | `pages.yml` é YAML válido |
| CT-009 | não se aplica | Contagens (17 regras, 17 referências, 19 templates) batem entre SKILL, README e página |
| CT-013 | RF-016 | `scan-linguagem.sh` acusa travessão e muleta em fixture ruim, e passa limpo no bom |
| CT-014 | RF-016 | Repositório inteiro sem travessão fora das citações em crases |
| CT-015 | RF-016 | Página justificada com hifenização em 1440 px, à esquerda em 375 px |
| CT-010 | RF-014 | Página sem rolagem horizontal e sem erro de console em 1440 px e 375 px, nos dois temas |
| CT-011 | RF-014 | Modo claro é o padrão; o botão alterna, persiste em `localStorage` e sobrevive ao reload |
| CT-012 | RF-014 | Toda classe usada em `docs/index.html` existe em `docs/tailwind.css` |

## 10. Evidências

| Afirmação | Fonte | Verificado |
| --- | --- | --- |
| O padrão do PDO para `ATTR_EMULATE_PREPARES` é ligado | php.net/manual/pt_BR/pdo.setattribute.php | ✅ 2026-09-05 |
| `password_hash` usa bcrypt em `PASSWORD_DEFAULT` | php.net/manual/pt_BR/function.password-hash.php | ✅ 2026-09-05 |
| `hash_equals` existe para comparação de tempo constante | php.net/manual/pt_BR/function.hash-equals.php | ✅ 2026-09-05 |
| `extractTo` de `ZipArchive` não protege contra traversal | OWASP · Snyk "Zip Slip" | ✅ 2026-09-05 |
| Tailwind não gera classe montada em runtime | tailwindcss.com/docs/detecting-classes-in-source-files | ✅ 2026-09-05 |
| Server Action é endpoint HTTP público | nextjs.org/docs/app/guides/authentication | ✅ 2026-09-05 |
| Formato Agent Skills | agentskills.io | ✅ 2026-09-05 |
| Tailwind v4 usa `prefers-color-scheme` por padrão; classe exige `@custom-variant` | tailwindcss.com/docs/dark-mode | ✅ 2026-09-05 |
| Item de grid tem `min-width: auto` e estica a coluna | medido no Chromium 141, 375 px | ✅ 2026-09-05 |
| `overflow` no `<body>` é propagado para o viewport | medido no Chromium 141 | ✅ 2026-09-05 |
| Empurrar `gh-pages` **não** habilita o Pages sozinho | 404 observado no repositório novo | ✅ 2026-09-05 |
| Convenções de linguagem em produtos financeiros | uxschwarz e alexhobigomes no Medium, lidos nesta sessão | ✅ 2026-09-05 |
| Vocabulário canônico de ITSM (incidente, requisição, problema) | ManageEngine, Qualitor, HDI Brasil, PenseemTI | ✅ 2026-09-05 |
| Justificar sem hifenizar abre rios de espaço | medido no Chromium 141 a 375 px | ✅ 2026-09-05 |
| Superfície do CLI e da API REST da Vercel | ⚠️ **não verificada**: vercel.com bloqueado pelo proxy desta sessão; a referência instrui o agente a confirmar com `vercel --help` e a doc | ⚠️ pendente |

## 11. Questões em aberto

1. Acrescentar uma terceira trilha (WordPress como tema/plugin) quando houver projeto que peça.
2. Publicar um app de demonstração construído sob este padrão, como o
   *Command Center for Dynatrace* é para a skill irmã.

---

## Aprovação

| | |
| --- | --- |
| **Aprovada em** | 2026-09-05 |
| **Por** | @adrianorafael |
| **Forma** | escopo definido no pedido inicial; nome e idioma decididos em um lote de perguntas |
