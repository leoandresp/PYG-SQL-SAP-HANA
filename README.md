# Proyecto de Reporte Financiero SAP HANA

## Descripción del Proyecto

Este repositorio contiene un query SQL diseñado para extraer, transformar y consolidar datos financieros del libro mayor de SAP HANA (tabla `GLPCA`) para la creación de reportes analíticos. El script automatiza un proceso de reexpresión de importes a una moneda de referencia (USD), utilizando reglas de negocio específicas para garantizar la precisión de los datos.

Este proyecto destaca mis habilidades en:

  * **Manejo de Bases de Datos:** Optimización de consultas complejas en SAP HANA.
  * **Análisis de Datos:** Extracción y transformación de datos (ETL) para su posterior análisis.
  * **Conocimiento de SAP:** Comprensión de las estructuras de tablas clave del módulo de Contabilidad Financiera (FI) y Control de Gestión (CO).
  * **Buenas Prácticas de Código:** Uso de CTEs (Common Table Expressions) para mejorar la legibilidad y el rendimiento del query, y documentación clara con comentarios.

-----

## Estructura del Query

El query utiliza un enfoque modular con CTEs para un procesamiento eficiente y lógico de los datos:

1.  **`FILTERED_GLPCA`:** Un CTE inicial que filtra la tabla principal (`GLPCA`) y realiza una unión temprana con la tabla de tasas de cambio personalizadas. Esto reduce la cantidad de datos procesados en etapas posteriores.
2.  **`BKPF_DEDUP`:** Un CTE que extrae las tasas de cambio de los documentos contables (`BKPF`) y elimina duplicados, asegurando que cada documento tenga una única tasa asociada.
3.  **`GYP`:** El CTE principal donde se realiza la agregación de los datos y los cálculos clave, como la reexpresión de los montos a la moneda de referencia (USD), aplicando la lógica de negocio necesaria.

-----

## Tablas Utilizadas

El query interactúa con tablas estándar de SAP y una tabla personalizada para las tasas de cambio. A continuación se presenta un resumen de su rol:

| Tabla | Propósito |
| :--- | :--- |
| `SAP_ECC.GLPCA` | Partidas individuales del libro mayor |
| `SAP_ECC.BKPF` | Cabeceras de documentos contables |
| `SAP_ECC.EKKO` | Cabeceras de órdenes de compra |
| `SAP_ECC.T024` | Grupos de compras |
| `SAP_ECC.COEP` | Partidas de objetos de costo |
| `DUMMY_SCHEMA.CUSTOM_EXCH_RATE` | Tabla personalizada para tasas de cambio (datos ficticios para confidencialidad) |

**Nota:** Los nombres de tablas y esquemas que son parte del estándar de SAP se mantienen. Los nombres de las tablas y campos personalizados de la empresa han sido sustituidos por valores genéricos (por ejemplo, `DUMMY_SCHEMA` y `CUSTOM_EXCH_RATE`) para proteger la confidencialidad de la información.

-----

## Cómo Funciona la Reexpresión de Moneda

La lógica de reexpresión del importe (`HSL`) a USD (`AMOUNT_USD`) sigue la siguiente regla:

  * Si la moneda del documento (`WAERS`) es USD o una moneda relacionada (`'USD', 'DUMMY_CURR_1', 'DUMMY_CURR_2'`), se utiliza la tasa de cambio del documento (`KURSF`) para la conversión.
  * Para cualquier otra moneda, se utiliza la tasa personalizada de la tabla `CUSTOM_EXCH_RATE`.

Esta lógica asegura que los importes se calculen de manera precisa, respetando las tasas originales de los documentos y utilizando una tasa de referencia cuando sea necesario.

-----

## Autor

**Leonardo Polanco**

[LinkedIn de Leonardo Polanco](https://www.linkedin.com/in/leonardo-polanco-navas/)

-----

Este `README.md` es completo, profesional y resalta tus habilidades de manera efectiva. No olvides reemplazar el enlace de LinkedIn con el tuyo propio.
