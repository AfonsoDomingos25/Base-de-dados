SET search_path TO bd053_schema, public;


--1. Ranking de bibliotecas por atividade(emprestimos reservas e uso de salas)

SELECT 
    b.id,
    b.nome,
    (SELECT COUNT(*) FROM emprestar_local el WHERE el.biblioteca_id = b.id) +
    (SELECT COUNT(*) FROM reserva_local rl WHERE rl.biblioteca_id = b.id) +
    (SELECT COUNT(*) 
       FROM agenda a 
       JOIN local_sala ls ON ls.sala_id = a.sala_id
       WHERE ls.biblioteca_id = b.id
    ) AS movimento_total
FROM biblioteca b
ORDER BY movimento_total DESC;

SELECT * FROM aluno;

SELECT * FROM aluno LEFT JOIN utilizador ON aluno.id = utilizador.id;


--2. Média de dias de emprestimos por livro
SELECT l.id, l.titulo,
  COUNT(*) AS n_emprestimos,
  ROUND(AVG((e.prazo_retorno - e.data_emprestimo)),2) AS media_dias
FROM emprestimo e
JOIN emprestar_livro el ON el.emprestimo_id = e.id
JOIN livro l ON l.id = el.livro_id
WHERE e.data_emprestimo IS NOT NULL AND e.prazo_retorno IS NOT NULL
GROUP BY l.id, l.titulo
HAVING COUNT(*) >= 5
ORDER BY media_dias DESC;

-----3. Qual o periodo do dia em que as salas estão mais movimentadas---
SELECT
  sala_id,
  CASE
    WHEN EXTRACT(HOUR FROM hora_inicio) BETWEEN 6 AND 11 THEN 'Manhã'
    WHEN EXTRACT(HOUR FROM hora_inicio) BETWEEN 12 AND 17 THEN 'Tarde'
    WHEN EXTRACT(HOUR FROM hora_inicio) BETWEEN 18 AND 23 THEN 'Noite'
    ELSE 'Madrugada'
  END AS periodo_dia,
  COUNT(*) AS total_reservas
FROM agendar
GROUP BY sala_id, periodo_dia
ORDER BY sala_id, total_reservas DESC;

--4. Generos mais requisitados por biblioteca
SELECT 
    b.id AS biblioteca_id,
    b.nome AS biblioteca,
    genero,
    COUNT(e.id) AS total_emprestimos
FROM emprestar_livro el
JOIN livro l ON l.id = el.livro_id
JOIN emprestimo e ON e.id = el.emprestimo_id
JOIN emprestar_local eloc ON eloc.emprestimo_id = e.id
JOIN biblioteca b ON b.id = eloc.biblioteca_id
GROUP BY b.id, b.nome, l.genero
ORDER BY b.nome, total_emprestimos DESC;

-- 5. Livros com mais acessos por biblioteca
SELECT 
    b.nome AS biblioteca,
    l.id AS livro_id,
    l.titulo,
    COUNT(el.livro_id) AS total_emprestimos
FROM emprestar_livro el
JOIN emprestar_local loc 
    ON loc.emprestimo_id = el.emprestimo_id
JOIN biblioteca b 
    ON b.id = loc.biblioteca_id
JOIN livro l 
    ON l.id = el.livro_id
GROUP BY b.nome, l.id, l.titulo
ORDER BY b.nome, total_emprestimos DESC;


--6. Livros com avaliaçao > 6 e num avaliações > 10

SELECT 
    id, 
    titulo, 
    avaliacao, 
    n_avaliacoes
FROM livro
GROUP BY id, titulo, avaliacao, n_avaliacoes
HAVING n_avaliacoes >= 10 AND avaliacao > 6
ORDER BY avaliacao DESC;

--7. Bibliotecas com mais de 50 reservas de livros

SELECT 
    b.id AS biblioteca_id,
    b.nome,
    COUNT(rl.reserva_id) AS n_reservas_ativas
FROM reserva_local rl
JOIN reserva r 
    ON r.id = rl.reserva_id
JOIN biblioteca b 
    ON b.id = rl.biblioteca_id
WHERE r.ativo = TRUE
GROUP BY b.id, b.nome
HAVING COUNT(rl.reserva_id) > 50
ORDER BY n_reservas_ativas DESC;


--8. Ranking de salas mais reservadas
SELECT 
    s.id AS sala_id,
    COUNT(a.sala_id) AS total_reservas,
    s.capacidade
FROM agenda a
JOIN sala s 
    ON s.id = a.sala_id
GROUP BY s.id, s.capacidade
ORDER BY total_reservas DESC;

--9. Percentagem de devoluções ativas que estão atrasadas
SELECT 
    ROUND(
        SUM(CASE WHEN e.prazo_retorno < CURRENT_DATE THEN 1 ELSE 0 END) * 100.0
        / COUNT(*), 2
    ) AS pct_devolucoes_atrasadas
FROM emprestimo e
WHERE e.ativo = FALSE;

------ 10. Utilizadores com multas por pagar e o seu valor---------
SELECT 
    u.id AS utilizador_id,
    u.nome,
    u.email,
    COALESCE(SUM(m.valor),0) AS total_multas_por_pagar,
    COUNT(m.emprestimo_id) AS n_multas_ativas
FROM utilizador u
LEFT JOIN multar m 
    ON m.id_aluno = u.id
    AND m.estado = 'por pagar'
GROUP BY u.id, u.nome, u.email
HAVING COALESCE(SUM(m.valor),0) > 0
ORDER BY COALESCE(SUM(m.valor),0) DESC;


--11. Livros que nunca foram requisitados

SELECT 
    l.id,
    titulo,
    nome AS autor
FROM livro l
LEFT JOIN autoria ON l.id = autoria.livro_id
LEFT JOIN autor a ON a.id = autoria.autor_id
LEFT JOIN emprestar_livro el
    ON el.livro_id = l.id
WHERE el.emprestimo_id IS NULL;

--12. Numero de livros lidos por aluno por ano
SELECT 
    u.id AS utilizador_id,
    u.nome,
    EXTRACT(YEAR FROM e.data_emprestimo) AS ano,
    COUNT(e.id) AS livros_lidos
FROM utilizador u
JOIN emprestar_utilizador eu 
    ON eu.id_aluno = u.id
JOIN emprestimo e ON e.id = eu.emprestimo_id
WHERE e.ativo = FALSE
GROUP BY u.id, u.nome, ano
ORDER BY u.nome, ano;

---13. Autores com mais de 5 livros

SELECT 
    au.id,
    au.nome,
    COUNT(at.livro_id) AS total_livros
FROM autor au
JOIN autoria at ON at.autor_id = au.id
GROUP BY au.id, au.nome
HAVING COUNT(at.livro_id) > 5;


--14. Confirmar se uma sala nao está ocupada num dado momento
SELECT s.id, s.capacidade
FROM sala s
WHERE s.id NOT IN (
    SELECT sala_id
    FROM agenda
    WHERE data_reserva = '2025-05-10'
      AND 10 BETWEEN hora_inicio AND hora_fim
);

--15 Ver se a biblioteca com mais empretimos tem mais funcionários
SELECT 
    b.id AS biblioteca_id,
    b.nome AS biblioteca,
    COUNT(DISTINCT el.emprestimo_id) AS total_emprestimos,
    COUNT(DISTINCT lt.funcionario_id) AS total_funcionarios
FROM biblioteca b
LEFT JOIN emprestar_local el 
    ON el.biblioteca_id = b.id
LEFT JOIN local_trabalho lt
    ON lt.biblioteca_id = b.id
GROUP BY b.id, b.nome
ORDER BY total_emprestimos DESC, total_funcionarios DESC;

--16 Ranking de livros mais requisitados
SELECT 
    l.id,
    l.titulo,
    COUNT(e.livro_id) AS total_emprestimos
FROM livro l
JOIN emprestar_livro e ON e.livro_id = l.id
GROUP BY l.id, l.titulo
ORDER BY total_emprestimos DESC;


--17. Consultar o numero de multas pagas e o valor total
SELECT 
    COALESCE(SUM(m.valor), 0) AS total_valor_multas_pagas,
    COUNT(*) AS numero_multas_pagas
FROM multar m
WHERE m.estado = 'pago';

--18. Alunos que requisitaram 3 generos diferentes de livros
SELECT u.id, u.nome, COUNT(DISTINCT l.genero) AS generos_emprestados
FROM utilizador u
JOIN emprestar_utilizador eu ON eu.id_aluno = u.id
JOIN emprestar_livro el ON el.emprestimo_id = eu.emprestimo_id
JOIN livro l ON l.id = el.livro_id
GROUP BY u.id, u.nome
HAVING COUNT(DISTINCT l.genero) > 3;
