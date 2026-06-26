-- ============================================================================
-- SCRIPT DE CREACIÓN DE BASE DE DATOS: "MERCADO LA PARADA"
-- Sistema de Gestión de Mercado Mayorista
-- Cumple con Buenas Prácticas de Normalización (3NF) y Estándares PostgreSQL
-- ============================================================================

-- Configuración de codificación y zona horaria por defecto para la sesión
SET client_encoding = 'UTF8';
SET timezone = 'America/Lima';

-- ----------------------------------------------------------------------------
-- ELIMINACIÓN DE TABLAS (ORDEN CORRECTO POR DEPENDENCIAS DE LLAVES FORÁNEAS)
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS asignaciones_puestos CASCADE;
DROP TABLE IF EXISTS puestos CASCADE;
DROP TABLE IF EXISTS estibajes CASCADE;
DROP TABLE IF EXISTS estibadores CASCADE;
DROP TABLE IF EXISTS transportistas CASCADE;
DROP TABLE IF EXISTS productos CASCADE;
DROP TABLE IF EXISTS categorias CASCADE;
DROP TABLE IF EXISTS comerciantes CASCADE;
DROP TABLE IF EXISTS usuarios CASCADE;
DROP TABLE IF EXISTS roles CASCADE;

-- ----------------------------------------------------------------------------
-- 1. CAPA DE SEGURIDAD Y USUARIOS (AUTENTICACIÓN JWT Y SESS_MGMT)
-- ----------------------------------------------------------------------------

-- Tabla de Roles del Sistema
CREATE TABLE roles (
    id_rol SERIAL PRIMARY KEY,
    nombre_rol VARCHAR(50) NOT NULL UNIQUE,
    descripcion TEXT,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE roles IS 'Almacena los roles de acceso al sistema (Administrador, Comerciante, Estibador, etc.).';

-- Tabla Principal de Usuarios
CREATE TABLE usuarios (
    id_usuario SERIAL PRIMARY KEY,
    id_rol INT NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    dni CHAR(8) NOT NULL UNIQUE,
    telefono VARCHAR(20),
    activo BOOLEAN DEFAULT TRUE,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_usuario_rol FOREIGN KEY (id_rol) REFERENCES roles(id_rol) ON DELETE RESTRICT
);
COMMENT ON TABLE usuarios IS 'Credenciales e información personal global para la autenticación JWT.';

-- ----------------------------------------------------------------------------
-- 2. CAPA DE NEGOCIO: COMERCIANTES Y LOGÍSTICA DE PUESTOS
-- ----------------------------------------------------------------------------

-- Tabla de Comerciantes (Extiende datos de negocio de ciertos usuarios)
CREATE TABLE comerciantes (
    id_comerciante SERIAL PRIMARY KEY,
    id_usuario INT NOT NULL UNIQUE,
    ruc CHAR(11) NOT NULL UNIQUE,
    razon_social VARCHAR(150) NOT NULL,
    tipo_comerciante VARCHAR(50) DEFAULT 'Mayorista', -- Mayorista, Minorista, Distribuidor
    CONSTRAINT fk_comerciante_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
);
COMMENT ON TABLE comerciantes IS 'Información comercial y tributaria específica de los comerciantes del mercado.';

-- Tabla de Puestos Físicos del Mercado
CREATE TABLE puestos (
    id_puesto SERIAL PRIMARY KEY,
    numero_puesto VARCHAR(10) NOT NULL UNIQUE,
    sector VARCHAR(50) NOT NULL, -- Ej: Frutas, Verduras, Carnes, Abarrotes
    area_metros_cuadrados NUMERIC(5,2) NOT NULL,
    estado_puesto VARCHAR(20) DEFAULT 'Disponible', -- Disponible, Ocupado, Mantenimiento
    CONSTRAINT chk_estado_puesto CHECK (estado_puesto IN ('Disponible', 'Ocupado', 'Mantenimiento'))
);
COMMENT ON TABLE puestos IS 'Ubicaciones físicas e inventario de espacios comerciales dentro del mercado.';

-- Tabla de Asignaciones de Puestos (Historial de alquiler/ocupación)
CREATE TABLE asignaciones_puestos (
    id_asignacion SERIAL PRIMARY KEY,
    id_comerciante INT NOT NULL,
    id_puesto INT NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE,
    monto_alquiler NUMERIC(10,2) NOT NULL,
    activo BOOLEAN DEFAULT TRUE,
    CONSTRAINT fk_asignacion_comerciante FOREIGN KEY (id_comerciante) REFERENCES comerciantes(id_comerciante) ON DELETE RESTRICT,
    CONSTRAINT fk_asignacion_puesto FOREIGN KEY (id_puesto) REFERENCES puestos(id_puesto) ON DELETE RESTRICT,
    CONSTRAINT chk_fechas CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio)
);
COMMENT ON TABLE asignaciones_puestos IS 'Relación histórica y contractual entre un comerciante y un puesto específico.';

-- ----------------------------------------------------------------------------
-- 3. CAPA DE INVENTARIO Y PRODUCTOS
-- ----------------------------------------------------------------------------

-- Tabla de Categorías de Productos
CREATE TABLE categorias (
    id_categoria SERIAL PRIMARY KEY,
    nombre_categoria VARCHAR(100) NOT NULL UNIQUE,
    descripcion TEXT
);
COMMENT ON TABLE categorias IS 'Clasificación taxonómica de los bienes comercializados.';

-- Tabla de Productos / Inventario por Comerciante
CREATE TABLE productos (
    id_producto SERIAL PRIMARY KEY,
    id_comerciante INT NOT NULL,
    id_categoria INT NOT NULL,
    nombre_producto VARCHAR(150) NOT NULL,
    descripcion TEXT,
    stock NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    unidad_medida VARCHAR(20) NOT NULL DEFAULT 'Kg', -- Saco, Caja, Kg, Tonelada
    precio_unitario NUMERIC(10,2) NOT NULL,
    ultima_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_producto_comerciante FOREIGN KEY (id_comerciante) REFERENCES comerciantes(id_comerciante) ON DELETE CASCADE,
    CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria) ON DELETE RESTRICT,
    CONSTRAINT chk_stock_positivo CHECK (stock >= 0),
    CONSTRAINT chk_precio_positivo CHECK (precio_unitario >= 0)
);
COMMENT ON TABLE productos IS 'Catálogo e inventario de productos gestionados independientemente por cada comerciante.';

-- ----------------------------------------------------------------------------
-- 4. CAPA DE TRANSPORTE Y OPERACIONES DE ESTIBAJE
-- ----------------------------------------------------------------------------

-- Tabla de Transportistas / Vehículos de Carga
CREATE TABLE transportistas (
    id_transportista SERIAL PRIMARY KEY,
    nombre_conductor VARCHAR(150) NOT NULL,
    dni_conductor CHAR(8) NOT NULL,
    placa_vehiculo VARCHAR(15) NOT NULL,
    tipo_vehiculo VARCHAR(50), -- Camión Furgón, Trailer, Pick-up
    empresa_transporte VARCHAR(100) DEFAULT 'Particular'
);
COMMENT ON TABLE transportistas IS 'Registro de vehículos de carga pesada y conductores que ingresan mercadería.';

-- Tabla de Estibadores (Operarios de carga y descarga)
CREATE TABLE estibadores (
    id_estibador SERIAL PRIMARY KEY,
    id_usuario INT NOT NULL UNIQUE,
    numero_carnet VARCHAR(20) NOT NULL UNIQUE,
    asociacion_gremio VARCHAR(100),
    estado_disponibilidad VARCHAR(20) DEFAULT 'Libre', -- Libre, Ocupado, Suspendido
    CONSTRAINT fk_estibador_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    CONSTRAINT chk_estado_estibador CHECK (estado_disponibilidad IN ('Libre', 'Ocupado', 'Suspendido'))
);
COMMENT ON TABLE estibadores IS 'Personal obrero encargado de la movilización interna de mercancías pesadas.';

-- Tabla de Servicios de Estibaje (Servicios solicitados)
CREATE TABLE estibajes (
    id_estibaje SERIAL PRIMARY KEY,
    id_comerciante INT NOT NULL,
    id_estibador INT NOT NULL,
    id_transportista INT,
    descripcion_carga TEXT NOT NULL,
    peso_toneladas NUMERIC(5,2),
    fecha_servicio TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    costo_servicio NUMERIC(10,2) NOT NULL,
    estado_servicio VARCHAR(20) DEFAULT 'Pendiente', -- Pendiente, En Proceso, Completado, Cancelado
    CONSTRAINT fk_estibaje_comerciante FOREIGN KEY (id_comerciante) REFERENCES comerciantes(id_comerciante) ON DELETE RESTRICT,
    CONSTRAINT fk_estibaje_estibador FOREIGN KEY (id_estibador) REFERENCES estibadores(id_estibador) ON DELETE RESTRICT,
    CONSTRAINT fk_estibaje_transportista FOREIGN KEY (id_transportista) REFERENCES transportistas(id_transportista) ON DELETE SET NULL,
    CONSTRAINT chk_estado_servicio CHECK (estado_servicio IN ('Pendiente', 'En Proceso', 'Completado', 'Cancelado')),
    CONSTRAINT chk_costo_positivo CHECK (costo_servicio >= 0)
);
COMMENT ON TABLE estibajes IS 'Registro operativo y económico de las transacciones de carga y descarga en el mercado.';


-- ----------------------------------------------------------------------------
-- 5. CREACIÓN DE ÍNDICES OPTIMIZADOS PARA RENDIMIENTO
-- ----------------------------------------------------------------------------

-- Índices para búsquedas de usuarios y autenticación rápida (JWT)
CREATE INDEX idx_usuarios_email ON usuarios (email);
CREATE INDEX idx_usuarios_dni ON usuarios (dni);

-- Índices comerciales para facturación y validaciones de identidad de negocio
CREATE INDEX idx_comerciantes_ruc ON comerciantes (ruc);

-- Índices operativos basados en rangos de fechas (Reportes y Auditoría)
CREATE INDEX idx_estibajes_fecha ON estibajes (fecha_servicio);
CREATE INDEX idx_asignaciones_fechas ON asignaciones_puestos (fecha_inicio, fecha_fin);

-- Índices de filtrado frecuente para mejorar operaciones de JOIN en microservicios
CREATE INDEX idx_productos_comerciante ON productos (id_comerciante);
CREATE INDEX idx_estibajes_estado ON estibajes (estado_servicio);


-- ----------------------------------------------------------------------------
-- 6. INSERCIÓN DE DATOS DE PRUEBA (DATA SEEDING)
-- ----------------------------------------------------------------------------

-- Inserción de Roles Básicos
INSERT INTO roles (nombre_rol, descripcion) VALUES
('Administrador', 'Acceso total a la configuración global y analítica del mercado.'),
('Comerciante', 'Gestión de inventarios, asignación de puestos y solicitudes de estibaje.'),
('Estibador', 'Acceso a visualización de tareas operativas y asignadas de carga.');

-- Inserción de 1 Administrador
INSERT INTO usuarios (id_rol, email, password_hash, nombres, apellidos, dni, telefono) VALUES
(1, 'admin.parada@mercado.gob.pe', '$2b$12$K39pX8gYVz9OOmH19fEqTuK2e.3lWhmHeF4iCAnb6uYRtP5kPsm3O', 'Carlos Antonio', 'Mendoza Ramos', '44556677', '987654321');

-- Inserción de Usuarios destinados a Comerciantes (3)
INSERT INTO usuarios (id_rol, email, password_hash, nombres, apellidos, dni, telefono) VALUES
(2, 'juan.perez@agroparada.com', '$2b$12$7xX8P7KzLmPqR9sTuVwXyOeF1a2b3c4d5e6f7g8h9i0j1k2l3m4n5', 'Juan Alberto', 'Pérez Quispe', '10203040', '912345678'),
(2, 'maria.delgado@frutaslima.pe', '$2b$12$8yY9Q8LaMnQrS0tUvWxZzPf2b3c4d5e6f7g8h9i0j1k2l3m4n5o6', 'María Elena', 'Delgado Flores', '20304050', '923456789'),
(2, 'distribuidora.huaman@gmail.com', '$2b$12$9zZ0R9MbNoStU1vWwXyAaQg3c4d5e6f7g8h9i0j1k2l3m4n5o6p7', 'Ricardo', 'Huamán Condori', '30405060', '934567890');

-- Inserción de Perfiles de Comerciantes asociados
INSERT INTO comerciantes (id_usuario, ruc, razon_social, tipo_comerciante) VALUES
(2, '20123456789', 'AGRO INDUSTRIAL PÉREZ S.A.C.', 'Mayorista'),
(3, '20987654321', 'FRUTAS FRESCAS LIMA E.I.R.L.', 'Mayorista'),
(4, '10304050601', 'RICARDO HUAMAN DISTRIBUIDORES', 'Distribuidor');

-- Inserción de Usuarios destinados a Estibadores (3)
INSERT INTO usuarios (id_rol, email, password_hash, nombres, apellidos, dni, telefono) VALUES
(3, 'pedro.cruz@estibadores.pe', '$2b$12$aS1bT2cU3dV4eW5fX6gYhZi7d8e9f0a1b2c3d4e5f6g7h8i9j0k1l', 'Pedro Pablo', 'Cruz Tello', '50607080', '945678901'),
(3, 'lucio.chavez@estibadores.pe', '$2b$12$bT2cU3dV4eW5fX6gYhZi8e9f0a1b2c3d4e5f6g7h8i9j0k1l2m3n', 'Lucio', 'Chávez Mamani', '60708090', '956789012'),
(3, 'marcos.solis@estibadores.pe', '$2b$12$cU3dV4eW5fX6gYhZi9e0f0a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5', 'Marcos Augusto', 'Solís Solano', '70809001', '967890123');

-- Inserción de Perfiles de Estibadores asociados
INSERT INTO estibadores (id_usuario, numero_carnet, asociacion_gremio, estado_disponibilidad) VALUES
(5, 'EST-2026-001', 'Sindicato Unificado de Estibadores La Parada', 'Ocupado'),
(6, 'EST-2026-002', 'Sindicato Unificado de Estibadores La Parada', 'Libre'),
(7, 'EST-2026-003', 'Asociación de Cargadores Autónomos Fuerza Mayor', 'Libre');

-- Inserción de Categorías
INSERT INTO categorias (nombre_categoria, descripcion) VALUES
('Tubérculos y Raíces', 'Papas, camotes, yucas, ollucos y productos relacionados.'),
('Frutas de Estación', 'Cítricos, manzanas, plátanos, mangos, frutas frescas en general.'),
('Hortalizas y Verduras', 'Cebollas, tomates, lechugas, zanahorias y verduras de hoja.');

-- Inserción de Productos por Comerciante
-- Comerciante 1: Juan Pérez
INSERT INTO productos (id_comerciante, id_categoria, nombre_producto, descripcion, stock, unidad_medida, precio_unitario) VALUES
(1, 1, 'Papa Única (Mayorista)', 'Sacos de papa única seleccionada de primera calidad', 1200.00, 'Saco', 45.00),
(1, 1, 'Camote Amarillo', 'Camote amarillo dulce de la costa central', 800.00, 'Kg', 1.80);

-- Comerciante 2: María Delgado
INSERT INTO productos (id_comerciante, id_categoria, nombre_producto, descripcion, stock, unidad_medida, precio_unitario) VALUES
(2, 2, 'Naranja Valencia', 'Naranjas jugosas para extractor en cajones grandes', 50.00, 'Caja', 35.00),
(2, 2, 'Plátano de Seda', 'Cajas de plátano de seda maduro traído de la selva central', 90.00, 'Caja', 28.50);

-- Comerciante 3: Ricardo Huamán
INSERT INTO productos (id_comerciante, id_categoria, nombre_producto, descripcion, stock, unidad_medida, precio_unitario) VALUES
(3, 3, 'Cebolla Roja Arequipana', 'Cebolla roja de exportación en mallas pesadas', 2500.00, 'Kg', 2.40);

-- Inserción de 2 Transportistas
INSERT INTO transportistas (nombre_conductor, dni_conductor, placa_vehiculo, tipo_vehiculo, empresa_transporte) VALUES
('Jorge Luis Cárdenas', '12983476', 'W4A-890', 'Camión Furgón Pesado', 'Transportes del Centro S.A.'),
('Héctor Raúl Palacios', '32847109', 'D7F-712', 'Trailer Platón', 'Logística Agropecuaria Express');

-- Inserción de 4 Puestos con sus respectivas asignaciones configuradas
INSERT INTO puestos (numero_puesto, sector, area_metros_cuadrados, estado_puesto) VALUES
('A-01', 'Tubérculos', 24.50, 'Ocupado'),
('A-02', 'Tubérculos', 20.00, 'Disponible'),
('B-15', 'Frutas', 30.00, 'Ocupado'),
('C-08', 'Verduras', 18.50, 'Ocupado');

-- Asignación de los puestos (4 registros asociados a los puestos creados)
INSERT INTO asignaciones_puestos (id_comerciante, id_puesto, fecha_inicio, fecha_fin, monto_alquiler, activo) VALUES
(1, 1, '2026-01-01', NULL, 1200.00, TRUE),   -- Juan Pérez en A-01
(2, 3, '2026-02-15', NULL, 1500.00, TRUE),   -- María Delgado en B-15
(3, 4, '2026-03-01', NULL, 950.00, TRUE),    -- Ricardo Huamán en C-08
(1, 2, '2025-01-01', '2025-12-31', 1100.00, FALSE); -- Histórico de Juan en A-02

-- Inserción de 5 Servicios de Estibaje en diferentes estados operativos
INSERT INTO estibajes (id_comerciante, id_estibador, id_transportista, descripcion_carga, peso_toneladas, fecha_servicio, costo_servicio, estado_servicio) VALUES
(1, 1, 1, 'Descarga de 200 sacos de Papa Única desde furgón centro.', 10.00, '2026-06-25 04:30:00', 180.00, 'Completado'),
(2, 2, 2, 'Carga y traslado de 50 cajas de Naranjas hacia almacén temporal.', 2.50, '2026-06-25 06:15:00', 70.00, 'Completado'),
(3, 1, NULL, 'Movilización interna manual de mallas de cebolla roja en sector C.', 1.20, '2026-06-25 08:00:00', 45.00, 'En Proceso'),
(1, 3, 1, 'Descarga complementaria de camote de chosica.', 3.00, '2026-06-25 09:30:00', 90.00, 'Pendiente'),
(2, 2, NULL, 'Reordenamiento logístico interno de cajas de plátano por daño estructural.', 0.80, '2026-06-25 10:00:00', 30.00, 'Cancelado');

-- ============================================================================
-- FIN DEL SCRIPT SQL - BASE DE DATOS OPERATIVA
-- ============================================================================
