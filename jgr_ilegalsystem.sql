CREATE TABLE IF NOT EXISTS `jgr_gangs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `color` varchar(10) NOT NULL,
  `ranks` longtext NOT NULL,
  `npc_model` varchar(50) NOT NULL,
  `npc_name` varchar(50) NOT NULL,
  `coords` longtext NOT NULL,
  `specialization` varchar(50) NOT NULL,
  `max_members` int(11) NOT NULL DEFAULT 10,
  `level` int(11) NOT NULL DEFAULT 0,
  `xp` int(11) NOT NULL DEFAULT 0,
  `stats` longtext NOT NULL DEFAULT '{}',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `jgr_gang_members` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `gang_name` varchar(50) NOT NULL,
  `citizenid` varchar(50) NOT NULL COMMENT 'QBCore citizenid or ESX identifier',
  `rank` varchar(50) NOT NULL,
  `joined_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `gang_name` (`gang_name`),
  KEY `citizenid` (`citizenid`),
  CONSTRAINT `fk_gang_name` FOREIGN KEY (`gang_name`) REFERENCES `jgr_gangs` (`name`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `jgr_societies` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `job_name` varchar(50) NOT NULL,
  `funds` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `job_name` (`job_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `jgr_plants` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `owner` varchar(50) NOT NULL,
  `seed_type` varchar(50) NOT NULL,
  `coords` longtext NOT NULL,
  `stage` int(11) NOT NULL DEFAULT 1,
  `water` int(11) NOT NULL DEFAULT 100,
  `planted_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `last_update` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
