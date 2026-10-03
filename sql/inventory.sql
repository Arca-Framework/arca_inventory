-- player, trunk, glovebox and stash inventories for arca_inventory
CREATE TABLE IF NOT EXISTS `arca_inventories` (
    `id` VARCHAR(100) NOT NULL,
    `items` LONGTEXT NOT NULL,
    `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
