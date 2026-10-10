# Changelog

Todas as mudanças relevantes de **<Nome do App>** são registradas aqui.

Formato: [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).
Versionamento: [SemVer](https://semver.org/lang/pt-BR/), aplicado como a regra **R13** do
[Development Pattern for Web Apps](https://github.com/adrianorafael/development-pattern-for-web-apps)
define: "quebrar" significa quebrar para **quem usa o aplicativo**.

A versão é mantida no campo `version` do `package.json`: ele é a fonte da verdade, não a
tag do Git.

Escreva cada entrada para quem **usa** o app, não para quem leu o diff.

Categorias, nesta ordem, só as que tiverem entrada:

- **Adicionado**, **Alterado**, **Corrigido**, **Removido**: as quatro de toda versão.
  O Keep a Changelog prevê também **Obsoleto** (o que vai sair numa versão futura) e
  **Segurança**; use-as quando houver o que dizer. Correção de segurança pode ir em
  Corrigido, marcada em negrito, com a urgência de atualizar.
- **Migrações**: cada arquivo, o que muda, se é aditiva ou destrutiva, e quanto pode levar.
- **Dependências**: cada pacote adicionado, atualizado de major ou removido, com a versão e
  o motivo. É o registro que permite, um ano depois, saber se um pacote ainda é necessário.
- **Privacidade** e **Configuração**: dado pessoal novo; variável de ambiente nova.

Mensagens de commit no formato `tipo: descrição` (`feat:`, `fix:`, `docs:`…); o
CHANGELOG não copia os commits, ele os traduz para quem usa.

## [Não publicado]

## [1.3.0] - 2026-09-05

### Adicionado
- Anexos em chamados: até 5 arquivos de 5 MB (PDF, JPG, PNG), guardados em área privada.

### Alterado
- A listagem de chamados passa a exibir um ícone quando há anexos.

### Corrigido
- Busca com apóstrofo (`O'Brien`) deixava a listagem em branco.
- **Segurança:** o download de anexo não verificava o dono do chamado: qualquer
  usuário autenticado conseguia baixar anexos de outros. **Atualize assim que possível.**

### Removido
- O aviso "envie os arquivos por e-mail para o suporte" na tela do chamado: os anexos o
  substituem.

### Migrações
- `20260905120000_adiciona_anexos.sql`, cria a tabela `anexos` (com RLS por dono) e o
  bucket privado `anexos` no Supabase Storage. Aditiva, sem perda de dados, e compatível
  com a versão 1.2.1 (o rollback do código continua seguro).
- `20260905120100_indice_status_data.sql`, índice composto em `chamados`. Pode levar
  alguns segundos em bases grandes.

### Privacidade
- A política de privacidade (`/politica-de-privacidade`) passa a citar os anexos: o que
  guardamos, para quê e por quanto tempo.

### Configuração
- Nenhuma variável nova: os anexos usam o projeto Supabase que o app já tem.

### Dependências
- Nenhuma nova: o tipo do arquivo é conferido pelos primeiros bytes com código do próprio
  app, sem pacote.

## [1.2.1] - 2026-08-20

### Corrigido
- Sessão expirava antes do tempo configurado em navegadores com fuso diferente do servidor.

## [1.0.0] - 2026-07-02

Primeira versão publicada.

### Adicionado
- Cadastro e login de usuários.
- CRUD de chamados com filtro por status e período.
- Ambiente validado na carga: o app avisa qual variável falta e onde configurá-la.
- Administrador inicial criado pelo seed, com senha vinda de variável de ambiente.

### Dependências
- Adicionado `next@<versão>`, `react@<versão>` e `tailwindcss@<versão>`: a base do app.
- Adicionado `@supabase/supabase-js@<versão>` e `@supabase/ssr@<versão>`: banco, login e
  arquivos, com a sessão em cookie.
- Adicionado `zod@<versão>`: validação dos formulários e das variáveis de ambiente.
