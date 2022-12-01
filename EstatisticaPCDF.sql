use PCDF;

WITH ValoresBase AS (
select 
	Nome,
	
	(CASE
		WHEN Turma = 'T1' THEN 1
		WHEN Turma = 'T2' THEN 2
		WHEN Turma = 'T3' THEN 3
	END) Turma,

	(CASE
		WHEN Relacionamento = 'Solteiro(a)' THEN 1
		WHEN Relacionamento = 'Casado(a)' THEN 2
		WHEN Relacionamento = 'Namorando' THEN 3
	END) Relacionamento,

	(CASE
		WHEN GeneroColegas = 'Não me importo de dividir moradia com pessoas de outro sexo.' THEN 1
		WHEN GeneroColegas = 'Gostaria de morar de preferencia com pessoas do meu gênero.' THEN 2
	END) GeneroColegas,

	(CASE 
		WHEN Cargo = 'Agente' THEN 10
		WHEN Cargo = 'Escrivão' THEN 5
		ELSE 3
	END) Cargo,

	(CASE
		WHEN QuartoIndividual = 'Topo dividir' THEN 5
		WHEN QuartoIndividual = 'Sim, se possível' THEN 3
		WHEN QuartoIndividual = 'Sim e não abro mão' THEN 1
	END) QuartoIndividual,

	(CASE
		WHEN Transporte = 'Não, vou a pé' THEN 1
		WHEN Transporte = 'Sim, moto' THEN 2
		WHEN Transporte = 'Não, vou de transporte público/uber' THEN 3
		WHEN Transporte = 'Gostaria de alugar um carro.' THEN 4
		WHEN Transporte = 'Sim, carro' THEN 5
	END) Transporte,

	(CASE 
		WHEN Imovel = 'Apartamento' THEN 8
		WHEN Imovel = 'Casa' THEN 4
		WHEN Imovel = 'Tanto faz' THEN 1
	END) Imovel,

	(CASE 
		WHEN Genero = 'Masculino' THEN 1
		WHEN Genero = 'Feminino' THEN 2
	END) Genero,

	(CASE 
		WHEN Cigarro = 'Não fumo e não gostaria de conviver com fumantes.' THEN 1
		WHEN Cigarro = 'Não fumo mas não me importaria de conviver com fumantes.' THEN 2
		WHEN Cigarro = 'Sou fumante ocasional' THEN -3
		WHEN Cigarro = 'Fumo todos os dias' THEN -4
	END) Cigarro,

	DefesaPessoal
from Moradia
)

, EscalaValores AS (
	
select 
	Nome,
	Relacionamento,
	(Imovel * 3) Imovel,
	(Cargo  * 3) Cargo,
	(Transporte * 3) Transporte, 
	(QuartoIndividual * 4) QuartoIndividual, 
	GeneroColegas, 

	(CASE
		WHEN Turma = 1 THEN 5
		ELSE 2
	END) Turma,

	(CASE
		WHEN (Relacionamento = 2 or Relacionamento = 3) and GeneroColegas = 2 THEN 5
		WHEN (Relacionamento = 2 or Relacionamento = 3) and GeneroColegas = 1 THEN 4
		WHEN Relacionamento = 1 and GeneroColegas = 1 THEN 5
		WHEN Relacionamento = 1 and GeneroColegas = 2 THEN 3
	END) RelacaoGenero,
	
	(CASE
		WHEN Genero = 2 AND GeneroColegas = 2 THEN 10
		WHEN Genero = 2 AND GeneroColegas = 1 THEN 5
		WHEN Genero = 1 AND GeneroColegas = 2 THEN 5
		ELSE 2
	END) Genero,

	(CASE
		WHEN Cigarro = 1 THEN 10
		WHEN Cigarro = 2 THEN 4
		WHEN Cigarro = 3 THEN 2
		WHEN Cigarro = 4 THEN 0
	END) Cigarro,

	DefesaPessoal
from ValoresBase
)

, DefindoScore AS (
select 
	Nome,
	Turma,
	(Turma + Relacionamento + GeneroColegas + Imovel + Cargo + QuartoIndividual + Transporte + Genero + Cigarro + DefesaPessoal) Score
from ValoresBase)


, DadosEstatisticos AS (
select 
	top 1
	(select 
		SUM(Turma + Relacionamento + GeneroColegas + Cargo + QuartoIndividual + Transporte + Genero + Cigarro + DefesaPessoal) Score
	from ValoresBase) TotalScore,

	(select AVG(Score) from DefindoScore) Media,

	(select COUNT(Nome) Qtd from ValoresBase) EspacoAmostral,

	(select CAST(STDEVP(Score) as numeric(18,2)) from DefindoScore) Desvio,

	CAST(SQRT((select COUNT(Nome) from ValoresBase)) as numeric(18,2)) RaizN

from ValoresBase
)

, Afinidade AS (
select 
	*, 
	CAST((ABS(Score - Media) / Desvio) as numeric(18,2)) ReducaoZ,
	CAST((CAST((ABS(Score - Media) / Desvio) as numeric(18,2)) * (Desvio / RaizN)) as numeric(18,2)) EstimativaErro,
	Score + CAST((CAST((ABS(Score - Media) / Desvio) as numeric(18,2)) * (Desvio / RaizN)) as numeric(18,2)) ErroMaxII,
	Score - CAST((CAST((ABS(Score - Media) / Desvio) as numeric(18,2)) * (Desvio / RaizN)) as numeric(18,2)) ErroMinII,
	Score + CAST((1.95 * (Desvio / RaizN)) as numeric(18,2)) ErroMax,
	Score - CAST((1.95 * (Desvio / RaizN)) as numeric(18,2)) ErroMin
from DefindoScore, DadosEstatisticos
)

, AfinidadeMacroT1 AS (
select 

	b1.Nome NomeB1,
	--b1.Score ScoreB1,
	--b1.ErroMin ErroMinB1,
	--b1.ErroMax ErroMaxB1,

	b2.Nome NomeB2
	--b2.Score ScoreB2,
	--b2.ErroMin ErroMinB2,
	--b2.ErroMax ErroMaxB2

from Afinidade b1
	join Afinidade b2 on b1.Nome <> b2.Nome
		and b1.Score between b2.ErroMin and b2.ErroMax
where 
	b1.Turma = 1 and b2.Turma = 1
group by 
	b1.Nome, b2.Nome
	
)

, SemGrupoT1 AS (
	select 
		a.Nome, 
		(select Media from DadosEstatisticos) Score
	from Afinidade a
	left join AfinidadeMacroT1 at1 on at1.NomeB1 = a.Nome
	where at1.NomeB1 is null
	and a.Turma = 1 
)

, AfinidadeT1 AS (
select 
	sg1.Nome NomeB1, 
	b1.Nome NomeB2 
from Afinidade b1
	join SemGrupoT1 sg1 on sg1.Nome <> b1.Nome
	and sg1.Score between b1.ErroMin and b1.ErroMax
	and b1.Turma = 1

union all

select * from AfinidadeMacroT1
)

, ValidacaoT1 AS (
select 
a.*,
vb1.Genero GeneroB1,
vb1.GeneroColegas GeneroColegasB1,
vb2.Genero GeneroB2,
vb2.GeneroColegas GeneroColegasB2
from AfinidadeT1 a
	join ValoresBase vb1 on vb1.Nome = a.NomeB1
	join ValoresBase vb2 on vb2.Nome = a.NomeB2
)

-- ######## Afinidade para T2 e T3 ###########

, AfinidadeMacroT2e3 AS (
select 

	b1.Nome NomeB1,
	--b1.Score ScoreB1,
	--b1.ErroMin ErroMinB1,
	--b1.ErroMax ErroMaxB1,

	b2.Nome NomeB2
	--b2.Score ScoreB2,
	--b2.ErroMin ErroMinB2,
	--b2.ErroMax ErroMaxB2

from Afinidade b1
	join Afinidade b2 on b1.Nome <> b2.Nome
		and b1.Score between b2.ErroMin and b2.ErroMax
where 
	b1.Turma <> 1 and b2.Turma <> 1
)

, SemGrupoT2 AS (
	select 
		a.Nome, 
		(select Media from DadosEstatisticos) Score
	from Afinidade a
	left join AfinidadeMacroT2e3 at1 on at1.NomeB1 = a.Nome
	where at1.NomeB1 is null
	and a.Turma <> 1 
)

, AfinidadeT2eT3 AS (
select 
	sg1.Nome NomeB1, 
	b1.Nome NomeB2 
from Afinidade b1
	join SemGrupoT2 sg1 on sg1.Nome <> b1.Nome
	and sg1.Score between b1.ErroMin and b1.ErroMax
	and b1.Turma <> 1

union all

select * from AfinidadeMacroT2e3
)

, ValidacaoT2e3 AS (
select 
a.*,
vb1.Genero GeneroB1,
vb1.GeneroColegas GeneroColegasB1,
vb2.Genero GeneroB2,
vb2.GeneroColegas GeneroColegasB2
from AfinidadeT2eT3 a
	join ValoresBase vb1 on vb1.Nome = a.NomeB1
	join ValoresBase vb2 on vb2.Nome = a.NomeB2
)

/*
Genero = 1 masculino; 2 feminino

GeneroColega = 1 outro sexo; 2 mesmo sexo
*/
, VerificarValidacao AS (
select 
*,
'T1' Turma,
(CASE
	WHEN (GeneroB1 = 2 and GeneroB2 = 2) and (GeneroColegasB1 = 2 and GeneroColegasB2 = 2) THEN 'Sim'
	WHEN GeneroColegasB1 = 1 and GeneroColegasB2 = 1  THEN 'Sim'
	WHEN (GeneroB1 = 2 and GeneroColegasB1 = 1) and GeneroColegasB2 = 1 THEN 'Sim'
	WHEN (GeneroB1 = 1 and GeneroB2 = 2) and (GeneroColegasB1 = 2) THEN 'Não'
	ELSE 'Não'
END) EhValido
from ValidacaoT1

union all

select 
*,
'T2e3' Turma,
(CASE
	WHEN (GeneroB1 = 2 and GeneroB2 = 2) and (GeneroColegasB1 = 2 and GeneroColegasB2 = 2) THEN 'Sim'
	WHEN GeneroColegasB1 = 1 and GeneroColegasB2 = 1  THEN 'Sim'
	WHEN (GeneroB1 = 2 and GeneroColegasB1 = 1) and GeneroColegasB2 = 1 THEN 'Sim'
	WHEN (GeneroB1 = 1 and GeneroB2 = 2) and (GeneroColegasB1 = 2) THEN 'Não'
	ELSE 'Não'
END) EhValido
from ValidacaoT2e3
)

, PessoasSelecionadas AS (
	select NomeB1, Turma from VerificarValidacao
	where EhValido = 'Sim'
	group by NomeB1, Turma
)

, AgrupamentoPessoas AS (
	select 
		ps.NomeB1,
		vv.NomeB2, 
		ps.Turma
	from PessoasSelecionadas ps
		join VerificarValidacao vv on vv.NomeB1 = ps.NomeB1	
	group by
		ps.NomeB1,
		vv.NomeB2, 
		ps.Turma
)

select * from AgrupamentoPessoas

