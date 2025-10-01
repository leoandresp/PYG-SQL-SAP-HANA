/*
* Propósito: Extrae y consolida datos de partidas individuales del libro mayor SAP (GLPCA) para la creación de reportes financieros. 
  El query transforma los datos para asegurar que los importes se reexpresen a una tasa de cambio específica, 
  manteniendo la precisión de la moneda original del documento, y excluyendo registros de la sociedad 'DUMMY_COMPANY_CODE'.
* Autor: Leonardo Polanco
* Fecha de Creación: 01/08/2025
* Última Modificación: 01/10/2025
* Tablas:
* SAP_ECC.GLPCA: Contiene las partidas individuales del libro mayor.
* DUMMY_SCHEMA.CUSTOM_EXCH_RATE: Almacena las tasas de cambio de monedas (reemplaza a la tabla personalizada).
* SAP_ECC.BKPF: Contiene los datos de las cabeceras de los documentos contables, incluyendo la moneda y la tasa de cambio del documento.
* SAP_ECC.EKKO: Tabla de cabeceras de documentos de compras.
* SAP_ECC.T024: Contiene los grupos de compras.
* SAP_ECC.COEP: Contiene las partidas de objetos de CO.
* Notas Importantes:
* La lógica de reexpresión del importe a USD utiliza la tasa de cambio del documento contable si la moneda es USD, 
  o la tasa de la tabla DUMMY_SCHEMA.CUSTOM_EXCH_RATE en caso contrario. Esto garantiza la precisión del cálculo.
* Se utiliza un CTE (Common Table Expression) llamado `FILTERED_GLPCA` para optimizar el rendimiento, ya que filtra los datos de la tabla `GLPCA` y realiza un `JOIN` con la tabla de tasas al inicio, 
  evitando reprocesar grandes volúmenes de datos.
*/
WITH FILTERED_GLPCA AS (
  -- CTE para filtrar y preprocesar los datos principales de GLPCA.
  SELECT
    B."EBELN", B."BUDAT", B."POPER", B."RYEAR", B."RACCT", B."HSL", B."MSL",
    B."USNAM", B."KOSTL", B."REFDOCNR",
    -- OPTIMIZACIÓN: Se incluye RATE_VALUE aquí para evitar un segundo JOIN más adelante.
    TA."RATE_VALUE" AS "CUSTOM_RATE",
    -- Generamos la clave de unión una sola vez.
    CASE
      WHEN B."AWTYP" IN ('MKPF', 'RMRP','PRCHG') THEN B."REFDOCNR" || B."AWORG"
      WHEN B."AWTYP" IN ('BKPF','BKPFF','AMDP','AMBU') THEN B."REFDOCNR" || B."KOKRS" || B."REFRYEAR"
      ELSE B."REFDOCNR"
    END AS "AWKEY_TO_JOIN"
  FROM "SAP_ECC"."GLPCA" AS B
  -- Usamos INNER JOIN para filtrar desde el inicio la mayor cantidad de filas posible.
  INNER JOIN "DUMMY_SCHEMA"."CUSTOM_EXCH_RATE" AS TA ON TA."RATE_DATE" = B."BUDAT"
  WHERE
    B."RYEAR" >= '2024' AND
    B."RBUKRS" <> 'DUMMY_COMPANY_CODE' AND -- Filtro para excluir la sociedad.
    TA."DUMMY_PLANT_CODE" = 'DUMMY_PLANT_CODE'
),

BKPF_DEDUP AS (
  -- CTE para obtener la tasa de cambio y la moneda del documento desde BKPF.
  -- Se desduplican los registros para evitar uniones cruzadas no deseadas.
  SELECT
    "AWKEY",
    "WAERS",
    "KURSF"
  FROM (
    SELECT
      bk."AWKEY",
      bk."WAERS",
      bk."KURSF",
      ROW_NUMBER() OVER(PARTITION BY bk."AWKEY" ORDER BY bk."AWKEY") AS "rn"
    FROM "SAP_ECC"."BKPF" AS bk
    -- INNER JOIN en lugar de "IN (SELECT...)" es más eficiente.
    -- Unimos BKPF solo con las claves únicas que realmente necesitamos de GLPCA.
    INNER JOIN (SELECT DISTINCT "AWKEY_TO_JOIN" FROM FILTERED_GLPCA) AS glpca_keys
      ON bk."AWKEY" = glpca_keys."AWKEY_TO_JOIN"
  )
  WHERE "rn" = 1
),

GYP AS (
  -- CTE para agregar y calcular los montos finales.
  SELECT
    B."EBELN",
    B."BUDAT"    AS "DATE",
    B."POPER"    AS "PERIOD",
    B."RYEAR"    AS "YEAR",
    B."RACCT"    AS "ACCOUNT",
    B."USNAM"    AS "USER",
    B."KOSTL"    AS "CENTRO_DE_COSTE",
    B."REFDOCNR" AS "Nro_Doc_Ref",
    COALESCE(T."EKGRP", '') AS "GCP",
    SUM(B."HSL") AS "AMOUNT",

    -- Cálculo del importe reexpresado a USD, usando la tasa del documento o la tasa de la tabla de tasas personalizada.
    CASE
      WHEN bk."WAERS" IN ('DUMMY_CURR_1', 'USD', 'DUMMY_CURR_2')
      THEN CASE
        -- Asumimos que es consistente por grupo, así que usamos MAX().
        WHEN MAX(B."MSL") = 0 AND B."EBELN" <> '' THEN 0
        ELSE ROUND(SUM(B."HSL") / MAX(bk."KURSF"), 2)
      END
      ELSE ROUND(SUM(B."HSL") / MAX(B."CUSTOM_RATE"), 2)
    END AS "AMOUNT_USD",
    bk."WAERS"    AS "CURRENCY_DOCUMENT",
    
    -- Monto del documento original.
    CASE
      WHEN bk."WAERS" IN ('DUMMY_CURR_1', 'USD', 'DUMMY_CURR_2')
      THEN CASE
        WHEN MAX(B."MSL") = 0 AND B."EBELN" <> '' THEN 0
        ELSE ROUND(SUM(B."HSL") / MAX(bk."KURSF"), 2)
      END
      ELSE ROUND(SUM(B."HSL"), 2)
    END AS "DOCUMENT_AMOUNT",

    -- Tasa de cambio utilizada en el cálculo.
    CASE WHEN bk."WAERS" IN ('DUMMY_CURR_1', 'USD', 'DUMMY_CURR_2') 
      THEN bk."KURSF" 
      ELSE B."CUSTOM_RATE" END AS "TASA"

  FROM FILTERED_GLPCA AS B
  
  -- Los LEFT JOIN se aplican sobre el conjunto ya filtrado de GLPCA.
  LEFT JOIN "SAP_ECC"."EKKO" AS E ON E."EBELN" = B."EBELN"
  LEFT JOIN "SAP_ECC"."T024" AS T ON T."EKGRP" = E."EKGRP"
  LEFT JOIN BKPF_DEDUP AS bk ON bk."AWKEY" = B."AWKEY_TO_JOIN"
  
  GROUP BY
    B."EBELN", B."BUDAT", B."POPER", B."RYEAR", B."RACCT", B."USNAM",
    B."KOSTL", B."REFDOCNR", T."EKGRP", bk."WAERS", bk."KURSF", B."CUSTOM_RATE"
)

-- Selección final de las columnas del CTE GYP.
SELECT
  G."DATE",
  G."PERIOD",
  G."YEAR",
  G."ACCOUNT",
  G."AMOUNT",
  G."AMOUNT_USD",
  G."USER",
  G."CENTRO_DE_COSTE",
  G."GCP",
  -- Subconsulta para obtener el número de documento de CO.
  COALESCE((SELECT MIN(C2."BELNR")FROM "SAP_ECC"."COEP" AS C2 WHERE C2."EBELN" = G."EBELN"), '') AS "Nro_Documento", 
  G."Nro_Doc_Ref",
  G."CURRENCY_DOCUMENT",
  G."DOCUMENT_AMOUNT",
  G."TASA"
FROM GYP AS A;
FROM AGG AS A;
