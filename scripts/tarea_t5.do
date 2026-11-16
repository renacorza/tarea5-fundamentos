pwd
cd "C:\Users\rato2\OneDrive\Documentos\Programación\tareas\tarea5-fundamentos"

* ============================================================
* T5 — Do-file automatizado
* Autor: Renato Cortez Zapata Fecha: 15-11-26
* ============================================================

clear all
set more off
capture mkdir "output"
capture log close
log using "output/tarea_t5.log", replace text

* --- Parámetros (lo único que se edita) ---
local datos "data/raw/casen_reducido.csv"
local depvar "ingreso"
local numericas "ingreso educ edad experiencia"
local controles "educ experiencia"
local grupos "sector region genero"
global umbral = 500000
global fuente "Elaboración propia en base a CASEN"

* Los locales son relacionados al ejercicio y no se traspasan si se está trabajando
* en un do-file diferente simultáneamente. Los globales se pueden conservar durante
* toda la sesión y entre distintos do-files.

import delimited "`datos'", clear varnames(1) encoding("utf-8")
generate experiencia = max(edad - educ - 6, 0)

generate mujer = genero == "F"
label define sino 0 "Hombre" 1 "Mujer"
label values mujer sino

foreach v of local numericas {
summarize `v', detail
}

forvalues t = 0(9)45 {
quietly count if experiencia >= `t' & experiencia < `t' + 9
display "Experiencia laboral de `t' a " `t' + 8 " años: " r(N) " personas"
}

capture program drop descriptivos_grupo
program define descriptivos_grupo
display _newline "=== Descriptivos por `1' ==="
tabulate `1'
tabstat ingreso educ, by(`1') statistics(mean sd n)
end

foreach g of local grupos {
descriptivos_grupo `g'
}

tempvar ing_miles
generate `ing_miles' = ingreso / 1000
summarize `ing_miles'

* Con tempvar se crea un nombre que se borra al terminar de correr, así la base
* de datos no se llena de variables que se usan una vez y después habría que
* borrar.

count if ingreso > $umbral & !missing(ingreso)

* Los valores perdidos en STATA se consideran mayores a cualquier número, por
* lo que hay que excluirlos específicamente usando !missing cuando hay una
* consición de mayor que.

quietly regress `depvar' `controles'
estimates store m1
quietly regress `depvar' `controles' i.mujer
estimates store m2
estimates table m1 m2, b(%9.0f) se stats(N r2) stfmt(%5.3f)

estimates restore m1
display "Beta educ m1: " _b[educ]
estimates restore m2
display "Beta educ m2: " _b[educ]

levelsof sector, local(sectores)
local k : word count `sectores'
matrix R = J(`k', 3, .)
local i = 1
foreach s of local sectores {
    quietly regress ingreso educ if sector == "`s'"
    matrix R[`i', 1] = _b[educ]
    matrix R[`i', 2] = _se[educ]
    matrix R[`i', 3] = e(N)
    local i = `i' + 1
}

matrix colnames R = beta_educ ee n
matrix rownames R = `sectores'
matrix list R, format(%9.0f)

putexcel set "output/tarea_t5_por_sector.xlsx", replace      
putexcel A1 = ("Sector") B1 = ("Beta educ") C1 = ("Error est.") D1 = ("n")
putexcel B2 = matrix(R)
local fila = 2
foreach s of local sectores {
    putexcel A`fila' = ("`s'")
    local fila = `fila' + 1
}
putexcel A9 = ("Fuente: $fuente")

log close

* El coeficiente de educación está relacionado positivamente con el ingreso.
* Por cada año adicional de educación, el ingreso aumenta en $42.019 y $42.246
* para m1 y m2, respectivamente. Al agregar la variable mujer, el r2 aumenta pero
* no se puede afirmar que esté mejorando la capacidad explicativa del modelo sin
* ver el r2 ajustado. Al tener las regresiones por sector, quedan muy pocas
* personas en cada una, el sector con más personas es Servicios con 15 y el que
* tiene menos es Construcción con 5, esto hace que la estimación no sea del todo
* confiable ya que un solo dato atípico puede alterar el estimador para el sector.