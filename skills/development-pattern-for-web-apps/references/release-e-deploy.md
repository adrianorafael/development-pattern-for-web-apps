# Release e deploy — versão, documentação e caminho de volta

> Regra **R13**: versão, documentação e schema andam juntos, no mesmo commit.
> Regra **R14**: nenhum deploy sem alvo nomeado, sem backup e sem caminho de volta.

---

## 1. Versionamento semântico, em termos de app

`MAJOR.MINOR.PATCH` — e o significado é **para quem usa o app**, não para quem o escreve.

| Nível | Quando | Exemplos |
| --- | --- | --- |
| **MAJOR** | Quebra algo para quem já usa | Migração que apaga coluna; mudança de URL de rota existente; requisito novo de ambiente (PHP 8.1 → 8.3); mudança que exige reconfiguração manual |
| **MINOR** | Funcionalidade nova, compatível | Módulo novo; campo novo opcional; painel novo; migração aditiva |
| **PATCH** | Correção sem mudança de comportamento esperado | Bug, ajuste de texto, correção de segurança sem quebra, melhoria de desempenho |

Duas decisões que quase todo mundo erra:

- **Correção de segurança que muda comportamento é MAJOR ou MINOR, não PATCH.** Se o
  usuário precisa refazer a senha ou reconectar, não é patch.
- **Migração que remove ou renomeia coluna é MAJOR**, mesmo que o diff tenha três linhas:
  quem não atualizar os arquivos junto fica com o app quebrado.

### Onde a versão vive

| Trilha | Fonte da verdade |
| --- | --- |
| PHP | `app/version.php` → `const APP_VERSAO = '1.3.0';` (ou `composer.json` → `version`) |
| Next.js | `package.json` → `version` |
| Banco | tabela `schema_migrations` — a última linha diz até onde o banco está |

Um arquivo de configuração é a fonte da verdade, não uma tag do Git. A tag é opcional; a
versão exibida no rodapé e no painel administrativo sai do arquivo.

**Exiba a versão na aplicação** — rodapé, ou tela "Sobre" do painel. Sem isso, ninguém sabe
o que está rodando naquele servidor.

---

## 2. O que muda junto com a versão

| A mudança… | Exige atualizar |
| --- | --- |
| Comportamento visível ao usuário | CHANGELOG, README (seção de uso), roteiro de QA |
| Requisito de ambiente (PHP, extensão) | README (pré-requisitos), verificação do Wizard (R9), `manifest.json` do pacote (R10) |
| Passo de instalação ou configuração | README (instalação), Wizard, `.env.example` |
| Schema do banco | Migração numerada, `schema_migrations`, README (se afeta backup) |
| Variável de ambiente nova | `.env.example`, README, painel da Vercel |
| Nova superfície de ataque | Spec (seção de segurança), roteiro de QA (casos `CT-SEC`) |
| Correção de defeito | CHANGELOG, caso `CT-REG-nnn` no roteiro |

Um commit que muda comportamento sem subir a versão e sem atualizar a documentação é, sob
este padrão, um **commit incompleto**.

---

## 3. CHANGELOG

Formato [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/), escrito para quem usa
o app — não para quem leu o diff.

```markdown
## [1.3.0] - 2026-09-05

### Adicionado
- Anexos em chamados: até 5 arquivos de 5 MB por chamado (PDF, JPG, PNG).

### Corrigido
- Busca com apóstrofo (`O'Brien`) deixava a listagem em branco.
- Download de anexo não verificava o dono do chamado — qualquer usuário autenticado
  conseguia baixar anexos de outros. **Atualize assim que possível.**

### Migrações
- `0007_adiciona_anexos.sql` — cria a tabela `anexos`. Aditiva, sem perda de dados.
- `0008_indice_status_data.sql` — índice composto em `chamados`. Pode levar alguns
  segundos em bases grandes.

### Requisitos
- Requer a extensão `fileinfo` (verificada pelo instalador).
- `storage/uploads/` precisa ser gravável.
```

Falha de segurança corrigida é **nomeada**, com a urgência de atualizar. Esconder isso do
CHANGELOG deixa quem usa a versão antiga sem saber que precisa subir.

---

## 4. A sequência de release

```bash
# 1. Validação completa (Fase 4)
npx tsc --noEmit && npm run lint && npm test && npm run build     # Next.js
find . -name '*.php' -not -path './vendor/*' -print0 | xargs -0 -n1 php -l   # PHP

# 2. Varreduras
bash skills/development-pattern-for-web-apps/assets/scripts/scan-secrets.sh
bash skills/development-pattern-for-web-apps/assets/scripts/scan-sql-injection.sh
composer audit || npm audit --omit=dev

# 3. QA (Fase 5): roteiro executado; nenhum defeito 🔴 em aberto

# 4. Versão + documentação, no MESMO commit
#    - versão no arquivo de configuração
#    - CHANGELOG com entrada datada
#    - README, se instalação/configuração/uso mudaram
#    - qa/roteiro-de-testes.md atualizado
#    - spec atualizada, se o comportamento mudou

# 5. Revisão (R12) contra o diff real
git diff --cached

# 6. ⛔ APROVAÇÃO — nomeando a versão e o que muda

git commit -m "feat(anexos): permitir anexar arquivos ao chamado

Fecha RF-012. Migração 0007 aditiva. Corrige também a verificação de dono
no download de anexos (CT-SEC-009 / DEF-014).

Versão 1.3.0."

git push -u origin feat/anexos-em-chamados
```

---

## 5. Deploy — Hostinger

⛔ **Portão.** Nomeie o alvo e espere o sim:

> Pronto para publicar **Controle de Chamados v1.3.0** em **`https://seu-dominio.com.br`**
> (Hostinger, `public_html/`). Uma migração pendente: `0007_adiciona_anexos.sql`, aditiva.
> Faço backup do banco e dos arquivos antes. Confirma?

Sequência:

1. **Backup do banco** — pelo hPanel, ou `mysqldump`, ou o backup automático do próprio
   painel de atualização (R10).
2. **Backup dos arquivos** que serão substituídos.
3. **Modo manutenção** ligado, se a atualização passa de alguns segundos.
4. **Enviar os arquivos.** Nunca `.git/`, `.env`, `config/app.config.php`, `node_modules/`,
   `tests/`, `specs/`, `qa/`.
5. **Rodar as migrações** — pelo painel de atualização, na ordem numérica, registrando em
   `schema_migrations`.
6. **Modo manutenção** desligado.
7. **Fumaça em produção:** a home carrega; o login entra; a tela do módulo alterado
   funciona; a versão exibida no rodapé é a nova; `curl -I` mostra os cabeçalhos.

**A forma preferida, depois da primeira instalação, é o próprio painel de atualização**
(R10): ele faz backup, valida, aplica na ordem e sabe voltar atrás. Enviar arquivo por FTP é
o caminho que esquece a migração.

### Rollback na Hostinger

Escreva isso **antes** de precisar dele, no README:

```
1. Ligar o modo manutenção.
2. Restaurar os arquivos do backup (storage/backups/<data>-v<anterior>/arquivos.zip).
3. Restaurar o banco (banco.sql) — pelo phpMyAdmin ou pelo painel.
4. Conferir se schema_migrations voltou à versão anterior.
5. Desligar o modo manutenção. Fumaça.
```

---

## 6. Deploy — Vercel

⛔ **Portão** também aqui. "É só um push" ainda é uma publicação.

| Ambiente | Origem | Uso |
| --- | --- | --- |
| Preview | cada branch/PR | **Onde o roteiro de QA (R11) é executado** |
| Production | `main` | Só depois do QA verde no preview |

Sequência:

1. Push no ramo de trabalho → preview deploy com URL própria.
2. Executar o roteiro de QA contra a URL de preview.
3. Nenhum defeito 🔴 aberto → ⛔ aprovação → merge em `main`.
4. Conferir no painel da Vercel que o build de produção terminou.
5. Fumaça em produção.

Cuidados específicos:

- **Migração de banco não acompanha o deploy da Vercel.** O código novo pode subir antes da
  migração rodar. Faça migrações **aditivas** e implante em duas etapas: primeiro a migração
  compatível com o código antigo, depois o código que a usa.
- **Variável de ambiente nova precisa existir no painel antes do deploy** que a usa —
  incluindo o ambiente de Preview.
- **Rollback é imediato:** *Deployments → deploy anterior → Promote to Production*. Mas o
  banco não volta junto: se a migração era destrutiva, o rollback do código não resolve.
  Por isso migração destrutiva é MAJOR e vem com plano próprio.

---

## 7. Migrações destrutivas — o padrão de três fases

Remover uma coluna sem derrubar o app leva **três releases**, não uma:

```
v1.4.0  Adiciona a coluna nova. O código escreve nas duas, lê da antiga.
v1.5.0  O código lê da nova. A antiga continua existindo, sem uso.
v1.6.0  Remove a coluna antiga.   ← só aqui, e com backup
```

É mais lento e é a diferença entre uma atualização entediante e uma noite perdida
restaurando dump.

---

## 8. Checklist de release

- [ ] Fase 4 (validação) completa, resultados reportados como são
- [ ] Fase 5 (QA) executada; nenhum defeito 🔴 em aberto
- [ ] Versão subida no arquivo de configuração, nível SemVer justificado
- [ ] CHANGELOG com entrada datada, escrita para o usuário
- [ ] README atualizado se instalação, configuração ou uso mudaram
- [ ] Roteiro de QA e spec atualizados no mesmo commit
- [ ] Migrações numeradas, idempotentes e testadas em base limpa **e** em base com dados
- [ ] Backup verificado — restaurado ao menos uma vez em ambiente de teste
- [ ] Rollback documentado no README
- [ ] Varreduras limpas; `composer audit`/`npm audit` sem crítico
- [ ] ⛔ Aprovação para o push, com a versão nomeada
- [ ] ⛔ Aprovação para o deploy, com o alvo nomeado
- [ ] Fumaça em produção depois de publicar, e o resultado relatado
