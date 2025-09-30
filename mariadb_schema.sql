-- Script de creación de base de datos y esquema para MariaDB
-- Dominios: usuarios, productos, clientes, ventas, compras y relaciones
-- Asunciones:
-- - Se incluye catálogo de categorías y proveedores
-- - Control de stock mediante triggers y tabla de movimientos
-- - Motor InnoDB y codificación utf8mb4

SET sql_mode = 'STRICT_ALL_TABLES';
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS simas_tpi_2025
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE simas_tpi_2025;

-- Asegurar motor por defecto
SET default_storage_engine = InnoDB;

-- =====================================================================
-- Tablas de configuración / catálogos
-- =====================================================================

CREATE TABLE IF NOT EXISTS roles (
	id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	nombre VARCHAR(50) NOT NULL UNIQUE,
	descripcion VARCHAR(255) NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS categorias (
	id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	nombre VARCHAR(100) NOT NULL UNIQUE,
	descripcion VARCHAR(255) NULL
) ENGINE=InnoDB;

-- =====================================================================
-- Seguridad / usuarios
-- =====================================================================

CREATE TABLE IF NOT EXISTS usuarios (
	id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	username VARCHAR(50) NOT NULL UNIQUE,
	email VARCHAR(150) NOT NULL UNIQUE,
	password_hash VARCHAR(255) NOT NULL,
	nombre VARCHAR(100) NULL,
	apellido VARCHAR(100) NULL,
	activo TINYINT(1) NOT NULL DEFAULT 1,
	rol_id INT UNSIGNED NULL,
	fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT fk_usuarios_roles FOREIGN KEY (rol_id) REFERENCES roles(id)
		ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

-- =====================================================================
-- Clientes y proveedores
-- =====================================================================

CREATE TABLE IF NOT EXISTS clientes (
	id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	tipo_doc ENUM('DNI','CUIT','CUIL','PASAPORTE','OTRO') NOT NULL DEFAULT 'DNI',
	nro_doc VARCHAR(20) NULL,
	nombre VARCHAR(150) NOT NULL,
	apellido VARCHAR(150) NULL,
	razon_social VARCHAR(200) NULL,
	email VARCHAR(150) NULL,
	telefono VARCHAR(50) NULL,
	direccion VARCHAR(255) NULL,
	ciudad VARCHAR(100) NULL,
	provincia VARCHAR(100) NULL,
	pais VARCHAR(100) NULL,
	codigo_postal VARCHAR(20) NULL,
	activo TINYINT(1) NOT NULL DEFAULT 1,
	UNIQUE KEY uk_clientes_doc (tipo_doc, nro_doc)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS proveedores (
	id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	razon_social VARCHAR(200) NOT NULL,
	tipo_doc ENUM('CUIT','CUIL','DNI','OTRO') NOT NULL DEFAULT 'CUIT',
	nro_doc VARCHAR(20) NULL,
	email VARCHAR(150) NULL,
	telefono VARCHAR(50) NULL,
	direccion VARCHAR(255) NULL,
	ciudad VARCHAR(100) NULL,
	provincia VARCHAR(100) NULL,
	pais VARCHAR(100) NULL,
	codigo_postal VARCHAR(20) NULL,
	activo TINYINT(1) NOT NULL DEFAULT 1,
	UNIQUE KEY uk_proveedores_doc (tipo_doc, nro_doc)
) ENGINE=InnoDB;

-- =====================================================================
-- Productos y stock
-- =====================================================================

CREATE TABLE IF NOT EXISTS productos (
	id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	sku VARCHAR(64) NOT NULL UNIQUE,
	nombre VARCHAR(200) NOT NULL,
	descripcion TEXT NULL,
	categoria_id INT UNSIGNED NULL,
	precio_venta DECIMAL(12,2) NOT NULL DEFAULT 0.00,
	costo DECIMAL(12,2) NOT NULL DEFAULT 0.00,
	stock_actual INT NOT NULL DEFAULT 0,
	activo TINYINT(1) NOT NULL DEFAULT 1,
	fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT fk_productos_categorias FOREIGN KEY (categoria_id) REFERENCES categorias(id)
		ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS movimientos_stock (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	producto_id INT UNSIGNED NOT NULL,
	tipo ENUM('COMPRA','VENTA','AJUSTE') NOT NULL,
	referencia_tipo ENUM('compra','venta','ajuste') NOT NULL,
	referencia_id BIGINT UNSIGNED NULL,
	cantidad INT NOT NULL,
	observacion VARCHAR(255) NULL,
	fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	INDEX idx_mov_stock_producto_fecha (producto_id, fecha),
	CONSTRAINT fk_mov_stock_producto FOREIGN KEY (producto_id) REFERENCES productos(id)
		ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- =====================================================================
-- Compras
-- =====================================================================

CREATE TABLE IF NOT EXISTS compras (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	proveedor_id INT UNSIGNED NOT NULL,
	usuario_id INT UNSIGNED NULL,
	fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	estado ENUM('BORRADOR','CONFIRMADA','ANULADA') NOT NULL DEFAULT 'CONFIRMADA',
	total DECIMAL(14,2) NOT NULL DEFAULT 0.00,
	observaciones VARCHAR(255) NULL,
	INDEX idx_compras_fecha (fecha),
	CONSTRAINT fk_compras_proveedor FOREIGN KEY (proveedor_id) REFERENCES proveedores(id)
		ON UPDATE CASCADE ON DELETE RESTRICT,
	CONSTRAINT fk_compras_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
		ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS compras_detalle (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	compra_id BIGINT UNSIGNED NOT NULL,
	producto_id INT UNSIGNED NOT NULL,
	cantidad INT NOT NULL,
	costo_unitario DECIMAL(12,2) NOT NULL,
	subtotal DECIMAL(14,2) GENERATED ALWAYS AS (cantidad * costo_unitario) VIRTUAL,
	INDEX idx_cd_compra (compra_id),
	INDEX idx_cd_producto (producto_id),
	CONSTRAINT fk_cd_compra FOREIGN KEY (compra_id) REFERENCES compras(id)
		ON UPDATE CASCADE ON DELETE CASCADE,
	CONSTRAINT fk_cd_producto FOREIGN KEY (producto_id) REFERENCES productos(id)
		ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- =====================================================================
-- Ventas
-- =====================================================================

CREATE TABLE IF NOT EXISTS ventas (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	cliente_id INT UNSIGNED NULL,
	usuario_id INT UNSIGNED NULL,
	fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	estado ENUM('BORRADOR','CONFIRMADA','ANULADA') NOT NULL DEFAULT 'CONFIRMADA',
	total DECIMAL(14,2) NOT NULL DEFAULT 0.00,
	observaciones VARCHAR(255) NULL,
	INDEX idx_ventas_fecha (fecha),
	CONSTRAINT fk_ventas_cliente FOREIGN KEY (cliente_id) REFERENCES clientes(id)
		ON UPDATE CASCADE ON DELETE SET NULL,
	CONSTRAINT fk_ventas_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
		ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ventas_detalle (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	venta_id BIGINT UNSIGNED NOT NULL,
	producto_id INT UNSIGNED NOT NULL,
	cantidad INT NOT NULL,
	precio_unitario DECIMAL(12,2) NOT NULL,
	subtotal DECIMAL(14,2) GENERATED ALWAYS AS (cantidad * precio_unitario) VIRTUAL,
	INDEX idx_vd_venta (venta_id),
	INDEX idx_vd_producto (producto_id),
	CONSTRAINT fk_vd_venta FOREIGN KEY (venta_id) REFERENCES ventas(id)
		ON UPDATE CASCADE ON DELETE CASCADE,
	CONSTRAINT fk_vd_producto FOREIGN KEY (producto_id) REFERENCES productos(id)
		ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- =====================================================================
-- Triggers para actualizar stock y registrar movimientos
-- =====================================================================

DELIMITER $$

CREATE TRIGGER trg_compra_detalle_after_insert
AFTER INSERT ON compras_detalle
FOR EACH ROW
BEGIN
	-- Aumenta stock por compras confirmadas
	DECLARE v_estado VARCHAR(20);
	SELECT estado INTO v_estado FROM compras WHERE id = NEW.compra_id;
	IF v_estado = 'CONFIRMADA' THEN
		UPDATE productos
		SET stock_actual = stock_actual + NEW.cantidad,
			fecha_actualizacion = CURRENT_TIMESTAMP
		WHERE id = NEW.producto_id;

		INSERT INTO movimientos_stock (producto_id, tipo, referencia_tipo, referencia_id, cantidad, observacion)
		VALUES (NEW.producto_id, 'COMPRA', 'compra', NEW.compra_id, NEW.cantidad, 'Ingreso por compra');
	END IF;
END$$

CREATE TRIGGER trg_venta_detalle_after_insert
AFTER INSERT ON ventas_detalle
FOR EACH ROW
BEGIN
	-- Reduce stock por ventas confirmadas
	DECLARE v_estado VARCHAR(20);
	SELECT estado INTO v_estado FROM ventas WHERE id = NEW.venta_id;
	IF v_estado = 'CONFIRMADA' THEN
		UPDATE productos
		SET stock_actual = stock_actual - NEW.cantidad,
			fecha_actualizacion = CURRENT_TIMESTAMP
		WHERE id = NEW.producto_id;

		INSERT INTO movimientos_stock (producto_id, tipo, referencia_tipo, referencia_id, cantidad, observacion)
		VALUES (NEW.producto_id, 'VENTA', 'venta', NEW.venta_id, NEW.cantidad, 'Egreso por venta');
	END IF;
END$$

-- Si se anula una compra, revertir stock
CREATE TRIGGER trg_compras_after_update
AFTER UPDATE ON compras
FOR EACH ROW
BEGIN
	IF OLD.estado = 'CONFIRMADA' AND NEW.estado = 'ANULADA' THEN
		-- Revertir cada detalle
		INSERT INTO movimientos_stock (producto_id, tipo, referencia_tipo, referencia_id, cantidad, observacion)
		SELECT cd.producto_id, 'AJUSTE', 'compra', NEW.id, -cd.cantidad, 'Reverso por anulación de compra'
		FROM compras_detalle cd WHERE cd.compra_id = NEW.id;

		UPDATE productos p
		JOIN compras_detalle cd ON cd.producto_id = p.id AND cd.compra_id = NEW.id
		SET p.stock_actual = p.stock_actual - cd.cantidad,
			p.fecha_actualizacion = CURRENT_TIMESTAMP;
	END IF;
	IF OLD.estado = 'BORRADOR' AND NEW.estado = 'CONFIRMADA' THEN
		-- Confirmación tardía: aplicar stock ahora
		INSERT INTO movimientos_stock (producto_id, tipo, referencia_tipo, referencia_id, cantidad, observacion)
		SELECT cd.producto_id, 'COMPRA', 'compra', NEW.id, cd.cantidad, 'Ingreso por compra (confirmación)'
		FROM compras_detalle cd WHERE cd.compra_id = NEW.id;

		UPDATE productos p
		JOIN compras_detalle cd ON cd.producto_id = p.id AND cd.compra_id = NEW.id
		SET p.stock_actual = p.stock_actual + cd.cantidad,
			p.fecha_actualizacion = CURRENT_TIMESTAMP;
	END IF;
END$$

-- Si se anula una venta, revertir stock
CREATE TRIGGER trg_ventas_after_update
AFTER UPDATE ON ventas
FOR EACH ROW
BEGIN
	IF OLD.estado = 'CONFIRMADA' AND NEW.estado = 'ANULADA' THEN
		INSERT INTO movimientos_stock (producto_id, tipo, referencia_tipo, referencia_id, cantidad, observacion)
		SELECT vd.producto_id, 'AJUSTE', 'venta', NEW.id, vd.cantidad, 'Reverso por anulación de venta'
		FROM ventas_detalle vd WHERE vd.venta_id = NEW.id;

		UPDATE productos p
		JOIN ventas_detalle vd ON vd.producto_id = p.id AND vd.venta_id = NEW.id
		SET p.stock_actual = p.stock_actual + vd.cantidad,
			p.fecha_actualizacion = CURRENT_TIMESTAMP;
	END IF;
	IF OLD.estado = 'BORRADOR' AND NEW.estado = 'CONFIRMADA' THEN
		INSERT INTO movimientos_stock (producto_id, tipo, referencia_tipo, referencia_id, cantidad, observacion)
		SELECT vd.producto_id, 'VENTA', 'venta', NEW.id, vd.cantidad, 'Egreso por venta (confirmación)'
		FROM ventas_detalle vd WHERE vd.venta_id = NEW.id;

		UPDATE productos p
		JOIN ventas_detalle vd ON vd.producto_id = p.id AND vd.venta_id = NEW.id
		SET p.stock_actual = p.stock_actual - vd.cantidad,
			p.fecha_actualizacion = CURRENT_TIMESTAMP;
	END IF;
END$$

DELIMITER ;

-- =====================================================================
-- Índices adicionales útiles
-- =====================================================================
CREATE INDEX idx_productos_nombre ON productos (nombre);
CREATE INDEX idx_clientes_nombre ON clientes (nombre, apellido, razon_social);
CREATE INDEX idx_proveedores_razon ON proveedores (razon_social);

-- =====================================================================
-- Vistas opcionales
-- =====================================================================
CREATE OR REPLACE VIEW v_stock_producto AS
SELECT
	p.id AS producto_id,
	p.sku,
	p.nombre,
	p.stock_actual,
	p.precio_venta,
	p.costo,
	c.nombre AS categoria
FROM productos p
LEFT JOIN categorias c ON c.id = p.categoria_id;

-- =====================================================================
-- Control de acceso por módulos/permisos
-- =====================================================================

CREATE TABLE IF NOT EXISTS modulos (
	id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	nombre VARCHAR(80) NOT NULL UNIQUE,
	descripcion VARCHAR(255) NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS permisos (
	id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	modulo_id INT UNSIGNED NOT NULL,
	codigo VARCHAR(80) NOT NULL,
	descripcion VARCHAR(255) NULL,
	UNIQUE KEY uk_perm_modulo_codigo (modulo_id, codigo),
	CONSTRAINT fk_permisos_modulo FOREIGN KEY (modulo_id) REFERENCES modulos(id)
		ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS roles_permisos (
	rol_id INT UNSIGNED NOT NULL,
	permiso_id INT UNSIGNED NOT NULL,
	PRIMARY KEY (rol_id, permiso_id),
	CONSTRAINT fk_rp_rol FOREIGN KEY (rol_id) REFERENCES roles(id)
		ON UPDATE CASCADE ON DELETE CASCADE,
	CONSTRAINT fk_rp_perm FOREIGN KEY (permiso_id) REFERENCES permisos(id)
		ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS usuarios_bloqueos (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	usuario_id INT UNSIGNED NOT NULL,
	motivo VARCHAR(255) NULL,
	desde DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	hasta DATETIME NULL,
	CONSTRAINT fk_ub_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
		ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- =====================================================================
-- Logística: depósitos, ubicaciones y movimientos internos
-- =====================================================================

CREATE TABLE IF NOT EXISTS depositos (
	id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	codigo VARCHAR(50) NOT NULL UNIQUE,
	nombre VARCHAR(150) NOT NULL,
	direccion VARCHAR(255) NULL,
	activo TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ubicaciones (
	id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	deposito_id INT UNSIGNED NOT NULL,
	codigo VARCHAR(50) NOT NULL,
	descripcion VARCHAR(255) NULL,
	UNIQUE KEY uk_ubi_deposito_codigo (deposito_id, codigo),
	CONSTRAINT fk_ubicaciones_deposito FOREIGN KEY (deposito_id) REFERENCES depositos(id)
		ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS stock_ubicacion (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	producto_id INT UNSIGNED NOT NULL,
	ubicacion_id INT UNSIGNED NOT NULL,
	cantidad INT NOT NULL DEFAULT 0,
	UNIQUE KEY uk_stock_ubi (producto_id, ubicacion_id),
	CONSTRAINT fk_su_producto FOREIGN KEY (producto_id) REFERENCES productos(id)
		ON UPDATE CASCADE ON DELETE CASCADE,
	CONSTRAINT fk_su_ubicacion FOREIGN KEY (ubicacion_id) REFERENCES ubicaciones(id)
		ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS movimientos_internos (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	producto_id INT UNSIGNED NOT NULL,
	origen_id INT UNSIGNED NULL,
	destino_id INT UNSIGNED NULL,
	cantidad INT NOT NULL,
	usuario_id INT UNSIGNED NULL,
	fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	observacion VARCHAR(255) NULL,
	CONSTRAINT fk_mi_producto FOREIGN KEY (producto_id) REFERENCES productos(id)
		ON UPDATE CASCADE ON DELETE RESTRICT,
	CONSTRAINT fk_mi_origen FOREIGN KEY (origen_id) REFERENCES ubicaciones(id)
		ON UPDATE CASCADE ON DELETE SET NULL,
	CONSTRAINT fk_mi_destino FOREIGN KEY (destino_id) REFERENCES ubicaciones(id)
		ON UPDATE CASCADE ON DELETE SET NULL,
	CONSTRAINT fk_mi_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
		ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

-- Parámetros de control por SKU
CREATE TABLE IF NOT EXISTS unidades_medida (
	id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	codigo VARCHAR(16) NOT NULL UNIQUE,
	descripcion VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

ALTER TABLE productos
	ADD COLUMN unidad_medida_id INT UNSIGNED NULL AFTER descripcion,
	ADD CONSTRAINT fk_productos_um FOREIGN KEY (unidad_medida_id) REFERENCES unidades_medida(id)
		ON UPDATE CASCADE ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS parametros_sku (
	producto_id INT UNSIGNED PRIMARY KEY,
	clasificacion_abc ENUM('A','B','C') NULL,
	stock_min INT NULL,
	stock_max INT NULL,
	punto_reorden INT NULL,
	lead_time_dias INT NULL,
	politica_reposicion ENUM('EOQ','ROP','MIN_MAX','OTRA') NULL,
	ubicacion_preferida_id INT UNSIGNED NULL,
	CONSTRAINT fk_psku_producto FOREIGN KEY (producto_id) REFERENCES productos(id)
		ON UPDATE CASCADE ON DELETE CASCADE,
	CONSTRAINT fk_psku_ubicacion FOREIGN KEY (ubicacion_preferida_id) REFERENCES ubicaciones(id)
		ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

-- =====================================================================
-- Gestión comercial: cotizaciones y pedidos de clientes
-- =====================================================================

CREATE TABLE IF NOT EXISTS cotizaciones (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	cliente_id INT UNSIGNED NOT NULL,
	usuario_id INT UNSIGNED NULL,
	fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	validez_hasta DATE NULL,
	estado ENUM('BORRADOR','ENVIADA','ACEPTADA','RECHAZADA','VENCIDA') NOT NULL DEFAULT 'BORRADOR',
	total DECIMAL(14,2) NOT NULL DEFAULT 0.00,
	observaciones VARCHAR(255) NULL,
	CONSTRAINT fk_cot_cliente FOREIGN KEY (cliente_id) REFERENCES clientes(id)
		ON UPDATE CASCADE ON DELETE RESTRICT,
	CONSTRAINT fk_cot_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
		ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS cotizaciones_detalle (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	cotizacion_id BIGINT UNSIGNED NOT NULL,
	producto_id INT UNSIGNED NOT NULL,
	descripcion VARCHAR(255) NULL,
	cantidad INT NOT NULL,
	precio_unitario DECIMAL(12,2) NOT NULL,
	subtotal DECIMAL(14,2) GENERATED ALWAYS AS (cantidad * precio_unitario) VIRTUAL,
	CONSTRAINT fk_cotd_cot FOREIGN KEY (cotizacion_id) REFERENCES cotizaciones(id)
		ON UPDATE CASCADE ON DELETE CASCADE,
	CONSTRAINT fk_cotd_producto FOREIGN KEY (producto_id) REFERENCES productos(id)
		ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS pedidos (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	cliente_id INT UNSIGNED NOT NULL,
	usuario_id INT UNSIGNED NULL,
	cotizacion_id BIGINT UNSIGNED NULL,
	fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	estado ENUM('REGISTRADO','APROBACION','APROBADO','PREPARACION','ENVIADO','ENTREGADO','CANCELADO') NOT NULL DEFAULT 'REGISTRADO',
	total DECIMAL(14,2) NOT NULL DEFAULT 0.00,
	observaciones VARCHAR(255) NULL,
	CONSTRAINT fk_ped_cliente FOREIGN KEY (cliente_id) REFERENCES clientes(id)
		ON UPDATE CASCADE ON DELETE RESTRICT,
	CONSTRAINT fk_ped_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
		ON UPDATE CASCADE ON DELETE SET NULL,
	CONSTRAINT fk_ped_cot FOREIGN KEY (cotizacion_id) REFERENCES cotizaciones(id)
		ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS pedidos_detalle (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	pedido_id BIGINT UNSIGNED NOT NULL,
	producto_id INT UNSIGNED NOT NULL,
	descripcion VARCHAR(255) NULL,
	cantidad INT NOT NULL,
	precio_unitario DECIMAL(12,2) NOT NULL,
	subtotal DECIMAL(14,2) GENERATED ALWAYS AS (cantidad * precio_unitario) VIRTUAL,
	CONSTRAINT fk_pedd_ped FOREIGN KEY (pedido_id) REFERENCES pedidos(id)
		ON UPDATE CASCADE ON DELETE CASCADE,
	CONSTRAINT fk_pedd_prod FOREIGN KEY (producto_id) REFERENCES productos(id)
		ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- =====================================================================
-- Facturación y cuentas por cobrar
-- =====================================================================

CREATE TABLE IF NOT EXISTS facturas_venta (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	venta_id BIGINT UNSIGNED NULL,
	pedido_id BIGINT UNSIGNED NULL,
	numero VARCHAR(50) NOT NULL,
	fecha DATE NOT NULL,
	cliente_id INT UNSIGNED NOT NULL,
	total DECIMAL(14,2) NOT NULL,
	estado ENUM('EMITIDA','ANULADA') NOT NULL DEFAULT 'EMITIDA',
	UNIQUE KEY uk_factura_numero (numero),
	CONSTRAINT fk_fv_venta FOREIGN KEY (venta_id) REFERENCES ventas(id)
		ON UPDATE CASCADE ON DELETE SET NULL,
	CONSTRAINT fk_fv_pedido FOREIGN KEY (pedido_id) REFERENCES pedidos(id)
		ON UPDATE CASCADE ON DELETE SET NULL,
	CONSTRAINT fk_fv_cliente FOREIGN KEY (cliente_id) REFERENCES clientes(id)
		ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS facturas_venta_detalle (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	factura_id BIGINT UNSIGNED NOT NULL,
	producto_id INT UNSIGNED NOT NULL,
	descripcion VARCHAR(255) NULL,
	cantidad INT NOT NULL,
	precio_unitario DECIMAL(12,2) NOT NULL,
	subtotal DECIMAL(14,2) GENERATED ALWAYS AS (cantidad * precio_unitario) VIRTUAL,
	CONSTRAINT fk_fvd_fv FOREIGN KEY (factura_id) REFERENCES facturas_venta(id)
		ON UPDATE CASCADE ON DELETE CASCADE,
	CONSTRAINT fk_fvd_prod FOREIGN KEY (producto_id) REFERENCES productos(id)
		ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS cuentas_cobrar (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	cliente_id INT UNSIGNED NOT NULL,
	factura_id BIGINT UNSIGNED NOT NULL,
	fecha_emision DATE NOT NULL,
	fecha_vencimiento DATE NULL,
	monto_total DECIMAL(14,2) NOT NULL,
	monto_pendiente DECIMAL(14,2) NOT NULL,
	estado ENUM('PENDIENTE','PAGADA','VENCIDA','PARCIAL') NOT NULL DEFAULT 'PENDIENTE',
	CONSTRAINT fk_cc_cliente FOREIGN KEY (cliente_id) REFERENCES clientes(id)
		ON UPDATE CASCADE ON DELETE RESTRICT,
	CONSTRAINT fk_cc_factura FOREIGN KEY (factura_id) REFERENCES facturas_venta(id)
		ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS cobros (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	cuenta_cobrar_id BIGINT UNSIGNED NOT NULL,
	fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	monto DECIMAL(14,2) NOT NULL,
	medio_pago ENUM('EFECTIVO','TRANSFERENCIA','TARJETA','CHEQUE','OTRO') NOT NULL,
	referencia VARCHAR(100) NULL,
	CONSTRAINT fk_cobros_cc FOREIGN KEY (cuenta_cobrar_id) REFERENCES cuentas_cobrar(id)
		ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS notas_credito (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	cliente_id INT UNSIGNED NOT NULL,
	factura_id BIGINT UNSIGNED NULL,
	numero VARCHAR(50) NOT NULL,
	fecha DATE NOT NULL,
	monto DECIMAL(14,2) NOT NULL,
	motivo VARCHAR(255) NULL,
	UNIQUE KEY uk_nc_numero (numero),
	CONSTRAINT fk_nc_cliente FOREIGN KEY (cliente_id) REFERENCES clientes(id)
		ON UPDATE CASCADE ON DELETE RESTRICT,
	CONSTRAINT fk_nc_factura FOREIGN KEY (factura_id) REFERENCES facturas_venta(id)
		ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS devoluciones_venta (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	venta_id BIGINT UNSIGNED NOT NULL,
	cliente_id INT UNSIGNED NOT NULL,
	fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	motivo VARCHAR(255) NULL,
	CONSTRAINT fk_devv_venta FOREIGN KEY (venta_id) REFERENCES ventas(id)
		ON UPDATE CASCADE ON DELETE RESTRICT,
	CONSTRAINT fk_devv_cliente FOREIGN KEY (cliente_id) REFERENCES clientes(id)
		ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- =====================================================================
-- Compras avanzadas: requisiciones, evaluaciones, recepciones, inspecciones
-- =====================================================================

CREATE TABLE IF NOT EXISTS requisiciones_compra (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	solicitante_id INT UNSIGNED NULL,
	fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	estado ENUM('ABIERTA','APROBADA','RECHAZADA','CERRADA','CANCELADA') NOT NULL DEFAULT 'ABIERTA',
	observaciones VARCHAR(255) NULL,
	CONSTRAINT fk_req_solicitante FOREIGN KEY (solicitante_id) REFERENCES usuarios(id)
		ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS requisiciones_detalle (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	requisicion_id BIGINT UNSIGNED NOT NULL,
	producto_id INT UNSIGNED NOT NULL,
	cantidad INT NOT NULL,
	descripcion VARCHAR(255) NULL,
	CONSTRAINT fk_reqd_req FOREIGN KEY (requisicion_id) REFERENCES requisiciones_compra(id)
		ON UPDATE CASCADE ON DELETE CASCADE,
	CONSTRAINT fk_reqd_producto FOREIGN KEY (producto_id) REFERENCES productos(id)
		ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS evaluaciones_proveedor (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	proveedor_id INT UNSIGNED NOT NULL,
	fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	puntualidad TINYINT NULL,
	calidad TINYINT NULL,
	precio TINYINT NULL,
	comentarios VARCHAR(255) NULL,
	CONSTRAINT fk_eval_prov FOREIGN KEY (proveedor_id) REFERENCES proveedores(id)
		ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- Recepción de compras (si se usa recepción física separada de la orden)
CREATE TABLE IF NOT EXISTS recepciones_compra (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	compra_id BIGINT UNSIGNED NOT NULL,
	fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	usuario_id INT UNSIGNED NULL,
	deposito_id INT UNSIGNED NULL,
	observaciones VARCHAR(255) NULL,
	CONSTRAINT fk_rec_compra FOREIGN KEY (compra_id) REFERENCES compras(id)
		ON UPDATE CASCADE ON DELETE CASCADE,
	CONSTRAINT fk_rec_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
		ON UPDATE CASCADE ON DELETE SET NULL,
	CONSTRAINT fk_rec_deposito FOREIGN KEY (deposito_id) REFERENCES depositos(id)
		ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS recepciones_detalle (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	recepcion_id BIGINT UNSIGNED NOT NULL,
	producto_id INT UNSIGNED NOT NULL,
	cantidad INT NOT NULL,
	ubicacion_id INT UNSIGNED NULL,
	CONSTRAINT fk_recd_rec FOREIGN KEY (recepcion_id) REFERENCES recepciones_compra(id)
		ON UPDATE CASCADE ON DELETE CASCADE,
	CONSTRAINT fk_recd_producto FOREIGN KEY (producto_id) REFERENCES productos(id)
		ON UPDATE CASCADE ON DELETE RESTRICT,
	CONSTRAINT fk_recd_ubic FOREIGN KEY (ubicacion_id) REFERENCES ubicaciones(id)
		ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS inspecciones_calidad (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	recepcion_id BIGINT UNSIGNED NOT NULL,
	producto_id INT UNSIGNED NOT NULL,
	resultado ENUM('APROBADO','RECHAZADO','CONDICIONAL') NOT NULL,
	cantidad_aprobada INT NULL,
	cantidad_rechazada INT NULL,
	observaciones VARCHAR(255) NULL,
	CONSTRAINT fk_ic_rec FOREIGN KEY (recepcion_id) REFERENCES recepciones_compra(id)
		ON UPDATE CASCADE ON DELETE CASCADE,
	CONSTRAINT fk_ic_prod FOREIGN KEY (producto_id) REFERENCES productos(id)
		ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- =====================================================================
-- Logística de salida: picking, embalaje y envíos
-- =====================================================================

CREATE TABLE IF NOT EXISTS picking_list (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	pedido_id BIGINT UNSIGNED NULL,
	venta_id BIGINT UNSIGNED NULL,
	fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	estado ENUM('ABIERTA','COMPLETA','CANCELADA') NOT NULL DEFAULT 'ABIERTA',
	CONSTRAINT fk_pl_pedido FOREIGN KEY (pedido_id) REFERENCES pedidos(id)
		ON UPDATE CASCADE ON DELETE SET NULL,
	CONSTRAINT fk_pl_venta FOREIGN KEY (venta_id) REFERENCES ventas(id)
		ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS picking_items (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	picking_id BIGINT UNSIGNED NOT NULL,
	producto_id INT UNSIGNED NOT NULL,
	ubicacion_id INT UNSIGNED NULL,
	cantidad INT NOT NULL,
	CONSTRAINT fk_pi_picking FOREIGN KEY (picking_id) REFERENCES picking_list(id)
		ON UPDATE CASCADE ON DELETE CASCADE,
	CONSTRAINT fk_pi_prod FOREIGN KEY (producto_id) REFERENCES productos(id)
		ON UPDATE CASCADE ON DELETE RESTRICT,
	CONSTRAINT fk_pi_ubic FOREIGN KEY (ubicacion_id) REFERENCES ubicaciones(id)
		ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS envios (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	cliente_id INT UNSIGNED NOT NULL,
	pedido_id BIGINT UNSIGNED NULL,
	venta_id BIGINT UNSIGNED NULL,
	fecha_salida DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	transportista VARCHAR(150) NULL,
	numero_guia VARCHAR(80) NULL,
	estado ENUM('EN_PREPARACION','EN_TRANSITO','ENTREGADO','DEVUELTO') NOT NULL DEFAULT 'EN_PREPARACION',
	CONSTRAINT fk_env_cliente FOREIGN KEY (cliente_id) REFERENCES clientes(id)
		ON UPDATE CASCADE ON DELETE RESTRICT,
	CONSTRAINT fk_env_pedido FOREIGN KEY (pedido_id) REFERENCES pedidos(id)
		ON UPDATE CASCADE ON DELETE SET NULL,
	CONSTRAINT fk_env_venta FOREIGN KEY (venta_id) REFERENCES ventas(id)
		ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS envios_items (
	id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	envio_id BIGINT UNSIGNED NOT NULL,
	producto_id INT UNSIGNED NOT NULL,
	cantidad INT NOT NULL,
	CONSTRAINT fk_ei_envio FOREIGN KEY (envio_id) REFERENCES envios(id)
		ON UPDATE CASCADE ON DELETE CASCADE,
	CONSTRAINT fk_ei_prod FOREIGN KEY (producto_id) REFERENCES productos(id)
		ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Fin del script
