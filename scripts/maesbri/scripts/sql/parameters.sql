DROP TABLE IF EXISTS parameter CASCADE;
CREATE TABLE parameter (
    id SERIAL NOT NULL,
    "name" CHARACTER VARYING NOT NULL,
    "table" CHARACTER VARYING NOT NULL,
    "value" NUMERIC NOT NULL,

    CONSTRAINT parameter_name_table_pkey PRIMARY KEY ("name", "table")
);

DROP INDEX IF EXISTS parameter_name_table_idx;
CREATE INDEX parameter_name_table_idx ON parameter USING gist ("name", "table");

INSERT INTO parameter ("name", "table", "value")
       VALUES
        ('albedo', 'water', 0.07),
        ('albedo', 'roads', 0.1),
        ('albedo', 'railways', 0.2),
        ('albedo', 'trees', 0.13),
        ('albedo', 'vegetation', 0.21),
        ('albedo', 'agricultural_areas', 0.11),
        ('albedo', 'built_up', 0.2),
        ('albedo', 'built_open_spaces', 0.45),
        ('albedo', 'dense_urban_fabric', 0.065),
        ('albedo', 'medium_urban_fabric', 0.11),
        ('albedo', 'low_urban_fabric', 0.15),
        ('albedo', 'public_military_industrial', 0.13),
        ('context', 'dense_urban_fabric', 1),
        ('context', 'medium_urban_fabric', 0.8),
        ('context', 'low_urban_fabric', 0.5),
        ('context', 'public_military_industrial', 0.5),
        ('emissivity', 'water', 0.96),
        ('emissivity', 'roads', 0.9),
        ('emissivity', 'railways', 0.85),
        ('emissivity', 'trees', 0.97),
        ('emissivity', 'vegetation', 0.96),
        ('emissivity', 'agricultural_areas', 0.95),
        ('emissivity', 'built_up', 0.85),
        ('emissivity', 'built_open_spaces', 0.9),
        ('emissivity', 'dense_urban_fabric', 0.9),
        ('emissivity', 'medium_urban_fabric', 0.9),
        ('emissivity', 'low_urban_fabric', 0.9),
        ('emissivity', 'public_military_industrial', 0.9),
        ('fua_tunnel', 'dense_urban_fabric', 1.2),
        ('fua_tunnel', 'medium_urban_fabric', 1.1),
        ('fua_tunnel', 'low_urban_fabric', 1.0),
        ('fua_tunnel', 'public_military_industrial', 1.0),
        ('hillshade_buildings', 'dense_urban_fabric', 0.6),
        ('hillshade_buildings', 'medium_urban_fabric', 0.8),
        ('hillshade_buildings', 'low_urban_fabric', 0.9),
        ('hillshade_buildings', 'public_military_industrial', 0.9),
        ('runoff', 'water', 0.1),
        ('runoff', 'roads', 0.9),
        ('runoff', 'railways', 0.2),
        ('runoff', 'trees', 0.05),
        ('runoff', 'vegetation', 0.18),
        ('runoff', 'agricultural_areas', 0.1),
        ('runoff', 'built_up', 0.9),
        ('runoff', 'built_open_spaces', 0.75),
        ('runoff', 'dense_urban_fabric', 0.7),
        ('runoff', 'medium_urban_fabric', 0.5),
        ('runoff', 'low_urban_fabric', 0.4),
        ('runoff', 'public_military_industrial', 0.5),
        ('transmissivity', 'water', 0.5),
        ('transmissivity', 'roads', 0.15),
        ('transmissivity', 'railways', 0.15),
        ('transmissivity', 'trees', 0.25),
        ('transmissivity', 'vegetation', 0.30),
        ('transmissivity', 'agricultural_areas', 0.25),
        ('transmissivity', 'built_up', 0.01),
        ('transmissivity', 'built_open_spaces', 0.05),
        ('transmissivity', 'dense_urban_fabric', 0.01),
        ('transmissivity', 'medium_urban_fabric', 0.02),
        ('transmissivity', 'low_urban_fabric', 0.05),
        ('transmissivity', 'public_military_industrial', 0.05),
        ('vegetation_shadow', 'water', 1),
        ('vegetation_shadow', 'roads', 1),
        ('vegetation_shadow', 'railways', 1),
        ('vegetation_shadow', 'trees', 0),
        ('vegetation_shadow', 'vegetation', 1),
        ('vegetation_shadow', 'agricultural_areas', 1),
        ('vegetation_shadow', 'built_up', 1),
        ('vegetation_shadow', 'built_open_spaces', 1);
