-- Table: public.road_types
-- DROP TABLE public.road_types;

CREATE TABLE public.road_types
(
  type_id integer NOT NULL,
  name text,
  CONSTRAINT road_types_pkey PRIMARY KEY (type_id)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE public.road_types
  OWNER TO postgres;

-- Index: public.road_types_type_id_idx

-- DROP INDEX public.road_types_type_id_idx;

CREATE INDEX road_types_type_id_idx
  ON public.road_types
  USING btree
  (type_id);


-- Table: public.speed_map
-- DROP TABLE public.speed_map;

CREATE TABLE public.speed_map
(
  road_type integer NOT NULL,
  state character(2) NOT NULL,
  speed_inside integer,
  speed_outside integer,
  CONSTRAINT speed_map_pkey PRIMARY KEY (road_type, state)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE public.speed_map
  OWNER TO postgres;

-- Index: public.speed_map_road_type_state_idx

-- DROP INDEX public.speed_map_road_type_state_idx;

CREATE INDEX speed_map_road_type_state_idx
  ON public.speed_map
  USING btree
  (road_type, state COLLATE pg_catalog."default");

-- Table: public.nodes_routing
-- DROP TABLE public.nodes_routing;

CREATE TABLE public.nodes_routing
(
  id bigint NOT NULL,
  osm_id bigint,
  geom geometry,
  is_inside boolean,
  state character(2),
  CONSTRAINT nodes_routing_pkey PRIMARY KEY (id)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE public.nodes_routing
  OWNER TO postgres;

-- Index: public.nodes_routing_id_idx

-- DROP INDEX public.nodes_routing_id_idx;

CREATE INDEX nodes_routing_id_idx
  ON public.nodes_routing
  USING btree
  (id);

-- Index: public.nodes_routing_osm_id_idx

-- DROP INDEX public.nodes_routing_osm_id_idx;

CREATE INDEX nodes_routing_osm_id_idx
  ON public.nodes_routing
  USING btree
  (osm_id);


