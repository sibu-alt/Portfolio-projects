--Select *
--From DataPortfolio..compact$
--order by 3,4

--Select *
--From DataPortfolio..compvac$
--order by 3,4 

Select country , date, total_cases, total_deaths, new_cases, population
from DataPortfolio..compact$
order by 1,2

Select  country, date, total_cases, population, (total_cases/nullif(population, 0))*100 as death_percentage
From DataPortfolio..compact$
--where country like '%Africa%'
order by 1,2 

select country, max (total_deaths) as totaldeathcount 
from DataPortfolio..compact$
--where country like '%South africa%'
where continent is not null
group by country
order by totaldeathcount desc

select  dea.continent, dea.country, dea.date, dea.population, vac.new_vaccinations
from DataPortfolio..compact$ dea
join DataPortfolio..compvac$ vac
on dea.country = vac.country
and dea.date = vac.date
where dea.continent is not null
order by 2,3

select  dea.continent, dea.country, dea.date, dea.population, vac.new_vaccinations
, sum (convert(float,vac.new_vaccinations)) over (partition by dea.country order by dea.country, dea.date) as rollingpeoplevac
from DataPortfolio..compact$ dea
join DataPortfolio..compvac$ vac
on dea.country = vac.country
and dea.date = vac.date
where dea.continent is not null
order by 2,3


with popvsvac ( continent, country, date, population, new_vaccinations, rollingpeoplevac)
as
(
select  dea.continent, dea.country, dea.date, dea.population, vac.new_vaccinations
, sum (convert(float,vac.new_vaccinations)) over (partition by dea.country order by dea.country, dea.date) as rollingpeoplevac
from DataPortfolio..compact$ dea
join DataPortfolio..compvac$ vac
on dea.country = vac.country
and dea.date = vac.date
where dea.continent is not null
--order by 2,3
)
select *, (rollingpeoplevac / population) *100
from popvsvac

Drop table if exists #percentpopulationvac
create table #percentpopulationvac
(
continent nvarchar(255),
location nvarchar(255),
date datetime,
population numeric,
new_vaccinations numeric,
rollingpeoplevac numeric,
)

insert into #percentpopulationvac
select  dea.continent, dea.country, dea.date, dea.population, vac.new_vaccinations
, sum (convert(float,vac.new_vaccinations)) over (partition by dea.country order by dea.country, dea.date) as rollingpeoplevac
from DataPortfolio..compact$ dea
join DataPortfolio..compvac$ vac
on dea.country = vac.country
and dea.date = vac.date
--where dea.continent is not null
--order by 2,3

Select *, (rollingpeoplevac / population) *100
from #percentpopulationvac


create view percentpopulationvac as
select  dea.continent, dea.country, dea.date, dea.population, vac.new_vaccinations
, sum (convert(float,vac.new_vaccinations)) over (partition by dea.country order by dea.country, dea.date) as rollingpeoplevac
from DataPortfolio..compact$ dea
join DataPortfolio..compvac$ vac
on dea.country = vac.country
and dea.date = vac.date
where dea.continent is not null
--order by 2,3

select * 
from percentpopulationvac