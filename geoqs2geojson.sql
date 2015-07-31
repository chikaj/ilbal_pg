CREATE OR REPLACE FUNCTION geoqs2geojson(
    param_table text,
    param_props text
) 
RETURNS json AS 
$$
DECLARE 
    var_geom_col text;
    var_table text;
    var_sql text;
    var_cols text;
    var_result json;

BEGIN
    -- select the geometry column name and the entire table name into the variables var_geom_col and var_table
    SELECT 
        f_geometry_column, 
        quote_ident(f_table_schema) || '.' || quote_ident(f_table_name) 
    FROM public.geometry_columns
    INTO var_geom_col, var_table
    WHERE f_table_schema || '.' || f_table_name = param_table
    LIMIT 1;
    -- end selection

    -- ensure a geometry column exists
    IF var_geom_col IS NULL THEN
        RAISE EXCEPTION 'No such geometry table as %', param_table;
    END IF;
    -- end geometry column check
  
    -- clean up field names requested for output geojson...really to prevent an injection attack
    SELECT string_agg(quote_ident(trim(a)), ',') 
    INTO var_cols
    FROM unnest(string_to_array(param_props, ',')) As a;
    -- end clean up
     
    var_sql := 
        'SELECT row_to_json(fc) 
        FROM (
            SELECT 
                ''FeatureCollection'' As type, 
                array_to_json(array_agg(f)) As features
            FROM (
                SELECT 
                    ''Feature'' As type, 
                    ST_AsGeoJSON(ST_Transform(lg.' || quote_ident(var_geom_col) || ', 4326))::json As geometry,
                    row_to_json((SELECT l FROM (SELECT ' || var_cols || ') As l)) As properties 
                FROM ' || var_table || ' As lg 
            ) As f
        ) As fc;';

    EXECUTE var_sql INTO var_result;
     
    RETURN var_result;
END;
$$
LANGUAGE plpgsql;

select geoqs2geojson('public.world_statesborder', 'id, name, pop2012');