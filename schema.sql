-- NovaMart virtual retail database (PostgreSQL)
-- Run this file first, then indexes.sql

CREATE TABLE loyalty_tiers (
    tier_id SMALLINT NOT NULL GENERATED ALWAYS AS IDENTITY,
    tier_name VARCHAR(30) NOT NULL UNIQUE,
    min_lifetime_spend NUMERIC(12,2) NOT NULL DEFAULT 0,
    discount_pct NUMERIC(5,2) NOT NULL DEFAULT 0 CHECK (discount_pct BETWEEN 0 AND 100),
    PRIMARY KEY (tier_id)
);

CREATE TABLE customers (
    customer_id INT NOT NULL GENERATED ALWAYS AS IDENTITY,
    first_name VARCHAR(60) NOT NULL,
    last_name VARCHAR(60) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    phone VARCHAR(20),
    date_of_birth DATE,
    tier_id SMALLINT,
    registered_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    marketing_opt_in BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (customer_id),
    CONSTRAINT fk_customers_tier_id FOREIGN KEY (tier_id) REFERENCES loyalty_tiers(tier_id)
);

CREATE TABLE addresses (
    address_id INT NOT NULL GENERATED ALWAYS AS IDENTITY,
    customer_id INT NOT NULL,
    address_type VARCHAR(10) NOT NULL CHECK (address_type IN ('SHIPPING','BILLING')),
    line1 VARCHAR(150) NOT NULL,
    line2 VARCHAR(150),
    city VARCHAR(80) NOT NULL,
    state_province VARCHAR(80),
    postal_code VARCHAR(15) NOT NULL,
    country_code CHAR(2) NOT NULL,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (address_id),
    CONSTRAINT fk_addresses_customer_id FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE categories (
    category_id INT NOT NULL GENERATED ALWAYS AS IDENTITY,
    parent_category_id INT,
    category_name VARCHAR(80) NOT NULL,
    PRIMARY KEY (category_id),
    UNIQUE (parent_category_id, category_name),
    CONSTRAINT fk_categories_parent_category_id FOREIGN KEY (parent_category_id) REFERENCES categories(category_id)
);

CREATE TABLE products (
    product_id INT NOT NULL GENERATED ALWAYS AS IDENTITY,
    sku VARCHAR(40) NOT NULL UNIQUE,
    product_name VARCHAR(150) NOT NULL,
    description TEXT,
    category_id INT NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),
    cost_price NUMERIC(10,2) NOT NULL CHECK (cost_price >= 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (product_id),
    CONSTRAINT fk_products_category_id FOREIGN KEY (category_id) REFERENCES categories(category_id)
);

CREATE TABLE suppliers (
    supplier_id INT NOT NULL GENERATED ALWAYS AS IDENTITY,
    supplier_name VARCHAR(120) NOT NULL UNIQUE,
    contact_name VARCHAR(100),
    email VARCHAR(150) NOT NULL,
    phone VARCHAR(20),
    country_code CHAR(2),
    lead_time_days SMALLINT NOT NULL DEFAULT 7 CHECK (lead_time_days >= 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (supplier_id)
);

CREATE TABLE product_suppliers (
    product_id INT NOT NULL,
    supplier_id INT NOT NULL,
    supplier_sku VARCHAR(40),
    supply_price NUMERIC(10,2) NOT NULL CHECK (supply_price >= 0),
    is_preferred BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (product_id, supplier_id),
    CONSTRAINT fk_product_suppliers_product_id FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT fk_product_suppliers_supplier_id FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id)
);

CREATE TABLE warehouses (
    warehouse_id SMALLINT NOT NULL GENERATED ALWAYS AS IDENTITY,
    warehouse_name VARCHAR(80) NOT NULL UNIQUE,
    city VARCHAR(80) NOT NULL,
    country_code CHAR(2) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (warehouse_id)
);

CREATE TABLE inventory (
    warehouse_id SMALLINT NOT NULL,
    product_id INT NOT NULL,
    quantity_on_hand INT NOT NULL DEFAULT 0 CHECK (quantity_on_hand >= 0),
    reorder_level INT NOT NULL DEFAULT 10 CHECK (reorder_level >= 0),
    reorder_quantity INT NOT NULL DEFAULT 50 CHECK (reorder_quantity > 0),
    last_updated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (warehouse_id, product_id),
    CONSTRAINT fk_inventory_warehouse_id FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id),
    CONSTRAINT fk_inventory_product_id FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE promotions (
    promo_id INT NOT NULL GENERATED ALWAYS AS IDENTITY,
    promo_code VARCHAR(30) NOT NULL UNIQUE,
    description VARCHAR(200),
    discount_type VARCHAR(10) NOT NULL CHECK (discount_type IN ('PERCENT','FIXED')),
    discount_value NUMERIC(10,2) NOT NULL CHECK (discount_value > 0),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    PRIMARY KEY (promo_id),
    CHECK (end_date >= start_date)
);

CREATE TABLE orders (
    order_id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY,
    customer_id INT NOT NULL,
    order_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(15) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','PAID','PACKED','SHIPPED','DELIVERED','CANCELLED','RETURNED')),
    shipping_address_id INT NOT NULL,
    billing_address_id INT NOT NULL,
    promo_id INT,
    subtotal_amount NUMERIC(12,2) NOT NULL CHECK (subtotal_amount >= 0),
    discount_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    shipping_fee NUMERIC(10,2) NOT NULL DEFAULT 0,
    total_amount NUMERIC(12,2) NOT NULL CHECK (total_amount >= 0),
    PRIMARY KEY (order_id),
    CONSTRAINT fk_orders_customer_id FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT fk_orders_shipping_address_id FOREIGN KEY (shipping_address_id) REFERENCES addresses(address_id),
    CONSTRAINT fk_orders_billing_address_id FOREIGN KEY (billing_address_id) REFERENCES addresses(address_id),
    CONSTRAINT fk_orders_promo_id FOREIGN KEY (promo_id) REFERENCES promotions(promo_id)
);

CREATE TABLE order_items (
    order_id BIGINT NOT NULL,
    line_no SMALLINT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),
    discount_amount NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
    PRIMARY KEY (order_id, line_no),
    CONSTRAINT fk_order_items_order_id FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT fk_order_items_product_id FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE payments (
    payment_id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY,
    order_id BIGINT NOT NULL,
    payment_method VARCHAR(20) NOT NULL CHECK (payment_method IN ('CARD','UPI','NET_BANKING','WALLET','COD')),
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    payment_status VARCHAR(12) NOT NULL CHECK (payment_status IN ('INITIATED','SUCCESS','FAILED','REFUNDED')),
    transaction_ref VARCHAR(80) UNIQUE,
    paid_at TIMESTAMP,
    PRIMARY KEY (payment_id),
    CONSTRAINT fk_payments_order_id FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

CREATE TABLE shipments (
    shipment_id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY,
    order_id BIGINT NOT NULL,
    warehouse_id SMALLINT NOT NULL,
    carrier VARCHAR(50),
    tracking_number VARCHAR(60) UNIQUE,
    shipment_status VARCHAR(15) NOT NULL DEFAULT 'PREPARING' CHECK (shipment_status IN ('PREPARING','IN_TRANSIT','DELIVERED','RETURNED')),
    shipped_at TIMESTAMP,
    delivered_at TIMESTAMP,
    PRIMARY KEY (shipment_id),
    CONSTRAINT fk_shipments_order_id FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT fk_shipments_warehouse_id FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id)
);

CREATE TABLE purchase_orders (
    po_id INT NOT NULL GENERATED ALWAYS AS IDENTITY,
    supplier_id INT NOT NULL,
    warehouse_id SMALLINT NOT NULL,
    po_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expected_date DATE,
    received_date DATE,
    po_status VARCHAR(12) NOT NULL DEFAULT 'DRAFT' CHECK (po_status IN ('DRAFT','SENT','PARTIAL','RECEIVED','CANCELLED')),
    PRIMARY KEY (po_id),
    CONSTRAINT fk_purchase_orders_supplier_id FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id),
    CONSTRAINT fk_purchase_orders_warehouse_id FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id)
);

CREATE TABLE purchase_order_items (
    po_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity_ordered INT NOT NULL CHECK (quantity_ordered > 0),
    quantity_received INT NOT NULL DEFAULT 0 CHECK (quantity_received >= 0),
    unit_cost NUMERIC(10,2) NOT NULL CHECK (unit_cost >= 0),
    PRIMARY KEY (po_id, product_id),
    CONSTRAINT fk_purchase_order_items_po_id FOREIGN KEY (po_id) REFERENCES purchase_orders(po_id),
    CONSTRAINT fk_purchase_order_items_product_id FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE product_reviews (
    review_id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY,
    product_id INT NOT NULL,
    customer_id INT NOT NULL,
    rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    review_text TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (review_id),
    UNIQUE (product_id, customer_id),
    CONSTRAINT fk_product_reviews_product_id FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT fk_product_reviews_customer_id FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE inventory_transactions (
    txn_id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY,
    product_id INT NOT NULL,
    warehouse_id SMALLINT NOT NULL,
    txn_type VARCHAR(20) NOT NULL CHECK (txn_type IN ('PURCHASE_RECEIPT','SALE','RETURN','ADJUSTMENT','TRANSFER')),
    quantity_change INT NOT NULL CHECK (quantity_change <> 0),
    reference_type VARCHAR(20),
    reference_id BIGINT,
    txn_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (txn_id),
    CONSTRAINT fk_inventory_transactions_product_id FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT fk_inventory_transactions_warehouse_id FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id)
);
