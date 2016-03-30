DO $$
DECLARE
--	CREATE TYPE edge_type AS TABLE of edges_routing%rowtype;
	way ways;
	node_id bigint;
	source_rec nodes_routing%rowtype;
	target_rec nodes_routing%rowtype;
	node_rec nodes_routing%rowtype;
	speed_fw integer := -1;
	speed_bw integer := -1;
	paid boolean := false;
	oneway boolean := false;
	counter integer := 0;
	idx integer := 0;
	idx_counter integer := 0;
	node_set geometry;
	dump geometry;
	node_split geometry[];
	edge_geom geometry := null;
	node_array geometry[];
  road_type integer := 1;
--	edge_list edge_type; 
BEGIN       
-- **************************************************************************************** DELETING CURRENT ROWS ****************************************************************************************
DELETE FROM edges_routing;
-- **************************************************************************************** EXTRACT SPEED ****************************************************************************************
FOR way IN (SELECT * FROM ways WHERE public."_isValidWay"(ways)) LOOP
-- 	RAISE NOTICE 'valid way = %', ST_AsText(way.linestring);
	node_id := 0;
	source_rec := NULL;
	target_rec := NULL;
	node_rec := NULL;
	speed_fw := -1;
	speed_bw := -1;
	paid := false;
	oneway := false;
	counter := 0;
	idx := 0;
	idx_counter := 0;
	node_set := NULL;
	dump := NULL;
	node_split := NULL;
	edge_geom := NULL;
	node_array := NULL;
	road_type := 1;
  	IF exist(way.tags, 'maxspeed') THEN -- maxspeed tag
--    RAISE NOTICE 'maxspeed tag for way % = %', way.id, way.tags->'maxspeed';
  		IF way.tags->'maxspeed' SIMILAR TO '(km/h|kmh|kph)' THEN
  			speed_fw := to_number(substring(way.tags->'maxspeed' from '#"%#" (km/h|kmh|kph)' for '#'), '999999999');
  		ELSE 
  			IF way.tags->'maxspeed' SIMILAR TO 'mph' THEN
  				speed_fw := to_number(substring(way.tags->'maxspeed' from '#"%#" mph' for '#'), '999999999') * 1.609;
  			ELSE
  				IF way.tags->'maxspeed' SIMILAR TO 'knots' THEN
  					speed_fw := to_number(substring(way.tags->'maxspeed' from '#"%#" knots' for '#'), '999999999') * 1.852;   
  				ELSE
					  speed_fw := to_number(substring(way.tags->'maxspeed' from '#"%#"' for '#'), '999999999');
  				END IF;
  			END IF;
  		END IF;
  		--speed_fw := ways.tags->'maxspeed';
  		speed_bw := speed_fw;
  	ELSE -- maxspeed:forward
  		IF exist(way.tags, 'maxspeed:forward') THEN
  			IF way.tags->'maxspeed:forward' SIMILAR TO '(km/h|kmh|kph)' THEN
  				speed_fw := to_number(substring(way.tags->'maxspeed:forward' from '#"%#" (km/h|kmh|kph)' for '#'), '999999999');
  			ELSE 
  				IF way.tags->'maxspeed:forward' SIMILAR TO 'mph' THEN
  					speed_fw := to_number(substring(way.tags->'maxspeed:forward' from '#"%#" mph' for '#'), '999999999') * 1.609;
  				ELSE
  					IF way.tags->'maxspeed:forward' SIMILAR TO 'knots' THEN
  						speed_fw := to_number(substring(way.tags->'maxspeed:forward' from '#"%#" knots' for '#'), '999999999') * 1.852; 
  				  ELSE
					    speed_fw := to_number(substring(way.tags->'maxspeed' from '#"%#"' for '#'), '999999999');
  					END IF;
  				END IF;
  			END IF;
  		END IF;
  	END IF;
  	IF exist(way.tags, 'maxspeed:backward') THEN -- maxspeed:backward
  		IF way.tags->'maxspeed:backward' SIMILAR TO '(km/h|kmh|kph)' THEN
  			speed_bw := to_number(substring(way.tags->'maxspeed:backward' from '#"%#" (km/h|kmh|kph)' for '#'), '999999999');
  		ELSE 
  			IF way.tags->'maxspeed:backward' SIMILAR TO 'mph' THEN
  				speed_bw := to_number(substring(way.tags->'maxspeed:backward' from '#"%#" mph' for '#'), '999999999') * 1.609;
  			ELSE
  				IF way.tags->'maxspeed:backward' SIMILAR TO 'knots' THEN
  					speed_bw := to_number(substring(way.tags->'maxspeed:backward' from '#"%#" knots' for '#'), '999999999') * 1.852;  
  				ELSE
					  speed_bw := to_number(substring(way.tags->'maxspeed' from '#"%#"' for '#'), '999999999');
  				END IF;
  			END IF;
  		END IF;
  	END IF;
  -- **************************************************************************************** EXTRACT PAID ****************************************************************************************
  	paid := exist(way.tags, 'toll') AND (way.tags->'toll' = 'yes');
  -- **************************************************************************************** EXTRACT ONEWAY ****************************************************************************************	
  	oneway := (exist(way.tags, 'oneway') AND (way.tags->'oneway' = 'yes')) OR (way.tags->'highway' = 'motorway');
  -- **************************************************************************************** EXTRACT ROAD TYPE ****************************************************************************************
    SELECT type_id INTO road_type FROM road_types WHERE way.tags->'highway' LIKE (CONCAT(road_types.name,'%'));
    IF road_type IS NULL THEN
  	SELECT type_id INTO road_type FROM road_types WHERE road_types.name = 'living_street';
    END IF;
  -- **************************************************************************************** FOREACH NODE IN WAY - PREPARE NODES **************************************************************************************** 
  	FOR dump IN (SELECT (dumb::geometry_dump).geom FROM (
  					SELECT (ST_DumpPoints(way.linestring)) AS dumb
  				) AS dumbb) LOOP
  		node_array := array_append(node_array, dump);
  	END LOOP;
  	counter := 0;
  	FOREACH node_id IN ARRAY way.nodes LOOP
  		SELECT * INTO node_rec FROM nodes_routing WHERE nodes_routing.osm_id = node_id;
  --		RAISE NOTICE 'noderec = %',node_rec;
  		counter := counter + 1;
  		IF edge_geom IS NULL THEN
  			edge_geom := ST_MakeLine(node_array[counter]);
  		ELSE
  			edge_geom := ST_AddPoint(edge_geom, node_array[counter]);
  		END IF;
  		IF node_rec IS NULL THEN
  		ELSE
  			target_rec := node_rec;
  			IF source_rec IS NULL THEN
  			ELSE
  				edge_geom = ST_SetSRID(edge_geom, 4326);
 -- 				RAISE NOTICE 'inserting geom: %', ST_AsText(edge_geom); 
  				INSERT INTO edges_routing 
  					(osm_id, is_paid, is_oneway, is_inside, speed_forward, speed_backward, length, road_type, state, geom, source_id, target_id, source_lon, source_lat, target_lon, target_lat)
  					VALUES
  					(way.id::bigint							-- osm_id
  					, paid									-- is_paid
  					, oneway								-- is_oneway
  					, false									-- is_inside
  					, speed_fw								-- speed_forward
  					, speed_bw								-- speed_backward
  					, (ST_Length(edge_geom, true) / 1000)	-- length
  					, road_type							-- road_type
  					, 'CZ'::character(2)					-- state
  					, edge_geom								-- geom
  					, source_rec.id							-- source_id
  					, target_rec.id							-- target_id
  					, ST_X(source_rec.geom) * 10000000		-- source_longitude
  					, ST_Y(source_rec.geom) * 10000000		-- source_latitude
  					, ST_X(target_rec.geom) * 10000000		-- target_longitude
  					, ST_Y(target_rec.geom) * 10000000		-- target_latitude
  					);
  				edge_geom := ST_MakeLine(node_array[counter]);
 -- 				RAISE NOTICE 'geom after insert: %', ST_AsText(edge_geom); 
  --				counter := counter - 1;
  			END IF;
  			source_rec := node_rec;
  		END IF;
  	END LOOP;
  	/*
  -- **************************************************************************************** SPLIT NODES ****************************************************************************************
  --	RAISE NOTICE 'node set = %', node_set;
  
  
  
  	
  	FOR dump IN (
  		SELECT (dumb::geometry_dump).geom FROM (
  		SELECT (ST_Dump(
  			ST_Split(
  				way.linestring, 
  				ST_Snap(
  					node_set
  					,way.linestring
  					,0.00000001
  				)
  			)
  		)) AS dumb )AS dumbie
  		ORDER BY (dumb::geometry_dump).path[1]
  	) LOOP
  		node_split := array_append(node_split, dump);
  	END LOOP;
  	
  --	RAISE NOTICE 'node split = %', node_split;
  	
  -- **************************************************************************************** FOREACH NODE IN WAY ****************************************************************************************
  	source_rec = null;
  	target_rec = null;
  	FOREACH node_id IN ARRAY way.nodes LOOP
  		SELECT * INTO node_rec FROM nodes_routing WHERE nodes_routing.osm_id = node_id;
  		IF node_rec IS NULL THEN
  		ELSE
  			target_rec := node_rec;
  --			RAISE NOTICE 'osm id = %, id = %', node_rec.osm_id,node_rec.id;
  			IF source_rec IS NULL THEN
  			ELSE
  				idx := idx + 1;
  
  				IF idx = 1 THEN
  					idx_counter = 2;
  				ELSE
  					idx_counter = 1;
  				END IF;
  				SELECT (dumb::geometry_dump).geom FROM (
  				SELECT (ST_Dump(
  					ST_Split(
  						way.linestring, 
  						ST_Snap(
  							ST_Union(
  								source_rec.geom,target_rec.geom
  								--(SELECT geom FROM nodes_routing) 
  							)
  							,way.linestring
  							,0.00000001
  						)
  					)
  				)) AS dumb )AS dumbie
  				INTO edge_geom
  				WHERE (dumb::geometry_dump).path[1] = idx_counter;
  -- **************************************************************************************** INSERT ****************************************************************************************
  				INSERT INTO edges_routing 
  					(osm_id, is_paid, is_oneway, is_inside, speed_forward, speed_backward, length, road_type, state, geom, source_id, target_id)
  					VALUES
  					(way.id::bigint							-- osm_id
  					, paid									-- is_paid
  					, oneway								-- is_oneway
  					, false									-- is_inside
  					, speed_fw								-- speed_forward
  					, speed_bw								-- speed_backward
  					, ST_Length(edge_geom)					-- length
  					, 1::integer							-- road_type
  					, 'CZ'::character(2)					-- state
  					, edge_geom								-- geom
  					, source_rec.id							-- source_id
  					, target_rec.id							-- target_id
  					);
  					
  				RETURN QUERY SELECT way.id::bigint,false, false, false, 1,1,1.0::double precision,1::integer,'CZ'::character(2),ST_SetSRID(ST_MakePoint(1,1),4326),source_rec.id, target_rec.id;
  			END IF;
  			source_rec := node_rec;
  		END IF;
  		--IF EXISTS(SELECT * FROM nodes_routing AS nodes WHERE nodes.osm_id = node_id) THEN
  		--END IF;
  	END LOOP;*/
  --	RETURN edge_list;
END LOOP;
END $$;
--RAISE NOTICE 'i want to print % and %', var1,var2;$BODY$
--  LANGUAGE plpgsql VOLATILE
--  COST 100;

--SELECT ST_AsText(geom), * FROM edges_routing LIMIT 30; 
