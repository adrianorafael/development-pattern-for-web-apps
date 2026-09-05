# Spec — <Nome da funcionalidade>

> Modelo de `specs/<nnnn>-<slug>.md`.
> Parte de "Development Pattern for Web Apps" — regra R3.
> Uma a três páginas. Se estiver ficando maior, quebre em duas specs.
> Escreva ANTES de qualquer linha de implementação, e **pare para aprovação**.

| | |
| --- | --- |
| **Spec** | `0003-anexos-em-chamados` |
| **Status** | 🟡 aguardando aprovação · 🟢 aprovada · 🔵 implementada · ⚪ descartada |
| **Autor** | <você> · assistida por agente |
| **Data** | 2026-09-05 |
| **Versão alvo** | 1.3.0 |
| **Trilha** | PHP + MySQL (Hostinger) · Next.js (Vercel) |
| **Nível de segurança** | N1 · **N2** · N3 · N4 — ver R7 |

---

## 1. Objetivo

Uma frase: o que o usuário passa a conseguir fazer que hoje não consegue.

> O usuário pode anexar arquivos a um chamado e baixá-los depois, sem precisar
> enviar por e-mail.

## 2. Fora de escopo

O que **não** entra. Existe para impedir o escopo de crescer sozinho durante o build.

- Pré-visualização de imagens dentro da tela do chamado.
- Anexos em comentários (só no chamado).
- Antivírus nos arquivos enviados.

## 3. Requisitos funcionais

Numerados, verificáveis, na voz do usuário. Cada um vira ao menos um caso de teste.

| # | Requisito |
| --- | --- |
| RF-001 | O usuário autenticado pode anexar até 5 arquivos ao seu próprio chamado. |
| RF-002 | Os formatos aceitos são PDF, JPG e PNG, com no máximo 5 MB cada. |
| RF-003 | O usuário vê a lista de anexos com nome original, tamanho e data. |
| RF-004 | O usuário pode baixar um anexo do seu próprio chamado. |
| RF-005 | O usuário pode remover um anexo que ele mesmo enviou, enquanto o chamado estiver aberto. |
| RF-006 | O administrador pode baixar anexos de qualquer chamado. |

## 4. Requisitos não funcionais

- O envio de um arquivo de 5 MB conclui em até 10 s em conexão de 5 Mbps.
- A listagem de anexos não acrescenta consulta por linha (sem N+1).
- Funciona em Chrome, Firefox e Safari, e em telas de 375 px.
- Navegação completa por teclado; rótulos associados a todos os campos.

## 5. Modelo de dados

```sql
CREATE TABLE anexos (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  chamado_id      BIGINT UNSIGNED NOT NULL,
  nome_original   VARCHAR(255) NOT NULL,
  nome_armazenado VARCHAR(64)  NOT NULL,
  mime            VARCHAR(100) NOT NULL,
  tamanho         INT UNSIGNED NOT NULL,
  criado_em       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_anexos_armazenado (nome_armazenado),
  KEY idx_anexos_chamado (chamado_id),
  CONSTRAINT fk_anexos_chamado FOREIGN KEY (chamado_id)
    REFERENCES chamados (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

- **Migração:** `0007_adiciona_anexos.sql` — aditiva, sem perda de dados.
- **Armazenamento:** `storage/uploads/`, fora do webroot. O nome em disco é gerado
  (`bin2hex(random_bytes(16))`), nunca o nome enviado pelo usuário.

## 6. Telas e rotas

URLs conforme R15: português, kebab-case, sem extensão, sem estrutura de pastas.

| Rota | O que faz | Componentes |
| --- | --- | --- |
| `GET /chamados/{id}` | Exibe o chamado e a lista de anexos | `ListaAnexos`, `FormUploadAnexo` |
| `POST /chamados/{id}/anexos` | Recebe o upload | — |
| `GET /anexos/{id}` | Entrega o arquivo, após verificar o dono | — |
| `POST /anexos/{id}/remover` | Remove o anexo | — |

**Rotas renomeadas nesta versão:** nenhuma.
*(Quando houver: `/antiga` → 301 → `/nova`, e a entrada correspondente no CHANGELOG.)*

**Estados de cada tela** — os quatro, sempre:

| Tela | Carregando | Vazio | Erro | Sucesso |
| --- | --- | --- | --- | --- |
| Lista de anexos | esqueleto de 2 linhas | "Nenhum anexo ainda" + botão | mensagem + tentar de novo | a lista |
| Upload | barra de progresso, botão desabilitado | — | mensagem por arquivo | anexo aparece na lista |

## 7. Regras de negócio

- Máximo de 5 anexos por chamado; o sexto é recusado com mensagem clara.
- Só o autor do chamado e administradores enxergam e baixam os anexos.
- Remover um anexo apaga o registro **e** o arquivo em disco.
- Fechar o chamado bloqueia novos envios; o download continua permitido.

## 8. Segurança

| Item | Decisão |
| --- | --- |
| **Nova superfície de ataque** | Upload de arquivo e download autenticado |
| **Autorização** | O dono entra na cláusula `WHERE` de toda consulta de anexo |
| **Validação de tipo** | `finfo` sobre o conteúdo real; `$_FILES['x']['type']` é ignorado |
| **Nome do arquivo** | Gerado pelo servidor; o original só é exibido, escapado |
| **Local de gravação** | `storage/uploads/`, fora do webroot, sem execução de PHP |
| **Entrega** | Sempre por script que confere autorização; nunca link direto |
| **Limites** | 5 MB por arquivo na aplicação e no servidor |
| **Novos segredos** | Nenhum |
| **Dado pessoal novo** | O conteúdo dos anexos pode conter — política de retenção: 2 anos |

## 9. Critérios de aceite

Um por requisito, em formato observável.

```
RF-001
  DADO um chamado aberto do próprio usuário, sem anexos
  QUANDO ele seleciona um PDF de 2 MB e envia
  ENTÃO o anexo aparece na lista com nome original, "2,0 MB" e a data de hoje,
    e a contagem passa a exibir "1 de 5"

RF-004 (negativo)
  DADO o usuário A autenticado
  QUANDO ele acessa /anexos/{id de um anexo do usuário B}
  ENTÃO a resposta é 404 e nenhum byte do arquivo é entregue
```

## 10. Casos de teste

Alimentam `qa/roteiro-de-testes.md` (R11).

| Caso | Cobre | Tipo |
| --- | --- | --- |
| CT-030 | RF-001 caminho feliz | Funcional |
| CT-031 | RF-002 arquivo de 6 MB recusado | Funcional |
| CT-032 | RF-002 arquivo .exe recusado | Funcional |
| CT-033 | RF-001 sexto anexo recusado | Fronteira |
| CT-034 | RF-003 estado vazio | Interface |
| CT-035 | RF-005 remoção apaga registro e arquivo | Integração |
| CT-SEC-020 | RF-004 anexo de outro usuário → 404 | Segurança (IDOR) |
| CT-SEC-021 | `teste.php` renomeado para `.jpg` é recusado | Segurança |
| CT-SEC-022 | Acesso direto a `storage/uploads/...` pelo navegador → 403 | Segurança |
| CT-SEC-023 | Nome com `<script>` é exibido escapado | Segurança (XSS) |
| CT-SEC-024 | `?arquivo=../../config/app.config.php` → 404 | Segurança (traversal) |
| CT-UI-020 | `/chamados/8/` e `/Chamados/8` → 301 para a forma canônica | Rotas |
| CT-UI-021 | `/anexos/abc` (id não numérico) → 404, sem erro 500 | Rotas |

## 11. Impacto na documentação e no release

- [ ] Versão: **1.3.0** (MINOR — funcionalidade nova, compatível)
- [ ] CHANGELOG: entrada em "Adicionado" + a migração
- [ ] README: pré-requisito `fileinfo`; `storage/uploads/` gravável
- [ ] Roteiro de QA: 11 casos novos, 5 deles de segurança
- [ ] Wizard: acrescentar `fileinfo` aos requisitos verificados (R9)
- [ ] Pacote de atualização: `manifest.json` com a migração `0007` (R10)

## 12. Evidências

| Afirmação | Fonte | Verificado |
| --- | --- | --- |
| `finfo` disponível no servidor | `php -m` lista `fileinfo` | ✅ 2026-09-05 |
| `upload_max_filesize` = 8M | `php -i` | ✅ 2026-09-05 |
| `move_uploaded_file` é a forma correta | php.net/manual/pt_BR/function.move-uploaded-file.php | ✅ 2026-09-05 |
| SVG é vetor de XSS | OWASP File Upload Cheat Sheet | ✅ 2026-09-05 |

## 13. Questões em aberto

1. Anexos devem ser mantidos quando o chamado é excluído, ou apagados junto?
   *(proposta: apagados — `ON DELETE CASCADE` + remoção do arquivo)*
2. O administrador pode remover anexo de outro usuário?
   *(proposta: sim, com registro em auditoria)*

---

## Aprovação

| | |
| --- | --- |
| **Aprovada em** | <data> |
| **Por** | <usuário> |
| **Forma** | revisada item a item · aprovada sem revisão ("pode fazer") |
| **Alterações pedidas** | <nenhuma / lista> |
