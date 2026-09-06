# Changelog

Todas as mudanças relevantes de **<Nome do App>** são registradas aqui.

Formato: [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).
Versionamento: [SemVer](https://semver.org/lang/pt-BR/), aplicado como a regra **R13** do
[Development Pattern for Web Apps](https://github.com/adrianorafael/development-pattern-for-web-apps)
define: "quebrar" significa quebrar para **quem usa o aplicativo**.

A versão é mantida em `<app/version.php | package.json>`, o arquivo de configuração é a
fonte da verdade, não a tag do Git.

Escreva cada entrada para quem **usa** o app, não para quem leu o diff.

## [Não publicado]

## [1.3.0] - 2026-09-05

### Adicionado
- Anexos em chamados: até 5 arquivos de 5 MB (PDF, JPG, PNG).

### Alterado
- A listagem de chamados passa a exibir um ícone quando há anexos.

### Corrigido
- Busca com apóstrofo (`O'Brien`) deixava a listagem em branco.
- **Segurança:** o download de anexo não verificava o dono do chamado: qualquer
  usuário autenticado conseguia baixar anexos de outros. **Atualize assim que possível.**

### Migrações
- `0007_adiciona_anexos.sql`, cria a tabela `anexos`. Aditiva, sem perda de dados.
- `0008_indice_status_data.sql`, índice composto em `chamados`. Pode levar alguns
  segundos em bases grandes.

### Requisitos
- Requer a extensão PHP `fileinfo` (verificada pelo instalador).
- `storage/uploads/` precisa ser gravável.

## [1.2.1] - 2026-08-20

### Corrigido
- Sessão expirava antes do tempo configurado em navegadores com fuso diferente do servidor.

## [1.0.0] - 2026-07-02

Primeira versão publicada.

### Adicionado
- Cadastro e login de usuários.
- CRUD de chamados com filtro por status e período.
- Wizard de instalação com verificação de dependências.
- Painel administrativo com instalador de pacotes de atualização.
