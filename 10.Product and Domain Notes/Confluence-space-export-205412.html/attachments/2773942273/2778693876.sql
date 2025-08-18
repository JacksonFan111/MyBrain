-- =============================================
-- Author:        JACKSON FAN
-- Create Date:   2024-10-17
-- Description:   Create, populate, and utilize FATCA.CountryReference table to retrieve ISO codes, handling edge cases
-- =============================================

-- =============================================
-- 0. Drop the FATCA.CountryReference table if it already exists
-- =============================================
IF OBJECT_ID('FATCA.CountryReference', 'U') IS NOT NULL
BEGIN
    DROP TABLE FATCA.CountryReference;
END
GO

-- =============================================
-- 1. Create the FATCA.CountryReference Table with Alpha-3 Code
-- =============================================
CREATE TABLE FATCA.CountryReference (
    ReferenceID INT IDENTITY(1,1) PRIMARY KEY, -- Unique identifier for each record
    ISOCode CHAR(2) NOT NULL,                 -- 2-letter ISO country code
    ISOCode3 CHAR(3) NULL,                     -- 3-letter ISO country code (can be NULL for aliases)
    Country NVARCHAR(255) NOT NULL,            -- Official country name or alias
    IsAlias BIT NOT NULL DEFAULT 0             -- Flag to indicate if the entry is an alias (1) or standard (0)
);
GO

-- =============================================
-- 2. Populate the FATCA.CountryReference Table with All Known Countries
-- =============================================

-- Insert Standard Country Names (IsAlias = 0)
INSERT INTO FATCA.CountryReference (ISOCode, ISOCode3, Country, IsAlias)
VALUES
    ('AF', 'AFG', 'Afghanistan', 0),
    ('AL', 'ALB', 'Albania', 0),
    ('DZ', 'DZA', 'Algeria', 0),
    ('AS', 'ASM', 'American Samoa', 0),
    ('AD', 'AND', 'Andorra', 0),
    ('AO', 'AGO', 'Angola', 0),
    ('AI', 'AIA', 'Anguilla', 0),
    ('AQ', 'ATA', 'Antarctica', 0),
    ('AG', 'ATG', 'Antigua and Barbuda', 0),
    ('AR', 'ARG', 'Argentina', 0),
    ('AM', 'ARM', 'Armenia', 0),
    ('AW', 'ABW', 'Aruba', 0),
    ('AU', 'AUS', 'Australia', 0),
    ('AT', 'AUT', 'Austria', 0),
    ('AZ', 'AZE', 'Azerbaijan', 0),
    ('BS', 'BHS', 'Bahamas', 0),
    ('BH', 'BHR', 'Bahrain', 0),
    ('BD', 'BGD', 'Bangladesh', 0),
    ('BB', 'BRB', 'Barbados', 0),
    ('BY', 'BLR', 'Belarus', 0),
    ('BE', 'BEL', 'Belgium', 0),
    ('BZ', 'BLZ', 'Belize', 0),
    ('BJ', 'BEN', 'Benin', 0),
    ('BM', 'BMU', 'Bermuda', 0),
    ('BT', 'BTN', 'Bhutan', 0),
    ('BO', 'BOL', 'Bolivia', 0),
    ('BA', 'BIH', 'Bosnia and Herzegovina', 0),
    ('BW', 'BWA', 'Botswana', 0),
    ('BV', 'BVT', 'Bouvet Island', 0),
    ('BR', 'BRA', 'Brazil', 0),
    ('IO', 'IOT', 'British Indian Ocean Territory', 0),
    ('BN', 'BRN', 'Brunei Darussalam', 0),
    ('BG', 'BGR', 'Bulgaria', 0),
    ('BF', 'BFA', 'Burkina Faso', 0),
    ('MM', 'MMR', 'Myanmar', 0),
    ('BI', 'BDI', 'Burundi', 0),
    ('KH', 'KHM', 'Cambodia', 0),
    ('CM', 'CMR', 'Cameroon', 0),
    ('CA', 'CAN', 'Canada', 0),
    ('CV', 'CPV', 'Cape Verde', 0),
    ('KY', 'CYM', 'Cayman Islands', 0),
    ('CF', 'CAF', 'Central African Republic', 0),
    ('TD', 'TCD', 'Chad', 0),
    ('CL', 'CHL', 'Chile', 0),
    ('CN', 'CHN', 'China', 0),
    ('CX', 'CXR', 'Christmas Island', 0),
    ('CC', 'CCK', 'Cocos (Keeling) Islands', 0),
    ('CO', 'COL', 'Colombia', 0),
    ('KM', 'COM', 'Comoros', 0),
    ('CG', 'COG', 'Congo', 0),
    ('CD', 'COD', 'Congo, The Democratic Republic of the', 0),
    ('CK', 'COK', 'Cook Islands', 0),
    ('CR', 'CRI', 'Costa Rica', 0),
    ('CI', 'CIV', 'Côte d''Ivoire', 0),
    ('HR', 'HRV', 'Croatia', 0),
    ('CU', 'CUB', 'Cuba', 0),
    ('CY', 'CYP', 'Cyprus', 0),
    ('CZ', 'CZE', 'Czech Republic', 0),
    ('DK', 'DNK', 'Denmark', 0),
    ('DJ', 'DJI', 'Djibouti', 0),
    ('DM', 'DMA', 'Dominica', 0),
    ('DO', 'DOM', 'Dominican Republic', 0),
    ('EC', 'ECU', 'Ecuador', 0),
    ('EG', 'EGY', 'Egypt', 0),
    ('SV', 'SLV', 'El Salvador', 0),
    ('GQ', 'GNQ', 'Equatorial Guinea', 0),
    ('ER', 'ERI', 'Eritrea', 0),
    ('EE', 'EST', 'Estonia', 0),
    ('ET', 'ETH', 'Ethiopia', 0),
    ('FK', 'FLK', 'Falkland Islands (Malvinas)', 0),
    ('FO', 'FRO', 'Faroe Islands', 0),
    ('FJ', 'FJI', 'Fiji', 0),
    ('FI', 'FIN', 'Finland', 0),
    ('FR', 'FRA', 'France', 0),
    ('GF', 'GUF', 'French Guiana', 0),
    ('PF', 'PYF', 'French Polynesia', 0),
    ('TF', 'ATF', 'French Southern Territories', 0),
    ('GA', 'GAB', 'Gabon', 0),
    ('GM', 'GMB', 'Gambia', 0),
    ('GE', 'GEO', 'Georgia', 0),
    ('DE', 'DEU', 'Germany', 0),
    ('GH', 'GHA', 'Ghana', 0),
    ('GI', 'GIB', 'Gibraltar', 0),
    ('GR', 'GRC', 'Greece', 0),
    ('GL', 'GRL', 'Greenland', 0),
    ('GD', 'GRD', 'Grenada', 0),
    ('GP', 'GLP', 'Guadeloupe', 0),
    ('GU', 'GUM', 'Guam', 0),
    ('GT', 'GTM', 'Guatemala', 0),
    ('GN', 'GIN', 'Guinea', 0),
    ('GW', 'GNB', 'Guinea-Bissau', 0),
    ('GY', 'GUY', 'Guyana', 0),
    ('HT', 'HTI', 'Haiti', 0),
    ('HM', 'HMD', 'Heard Island and McDonald Islands', 0),
    ('HN', 'HND', 'Honduras', 0),
    ('HK', 'HKG', 'Hong Kong', 0),
    ('HU', 'HUN', 'Hungary', 0),
    ('IS', 'ISL', 'Iceland', 0),
    ('IN', 'IND', 'India', 0),
    ('ID', 'IDN', 'Indonesia', 0),
    ('IR', 'IRN', 'Iran, Islamic Republic of', 0),
    ('IQ', 'IRQ', 'Iraq', 0),
    ('IE', 'IRL', 'Ireland', 0),
    ('IM', 'IMN', 'Isle of Man', 0),
    ('IL', 'ISR', 'Israel', 0),
    ('IT', 'ITA', 'Italy', 0),
    ('JM', 'JAM', 'Jamaica', 0),
    ('JP', 'JPN', 'Japan', 0),
    ('JE', 'JEY', 'Jersey', 0),
    ('JO', 'JOR', 'Jordan', 0),
    ('KZ', 'KAZ', 'Kazakhstan', 0),
    ('KE', 'KEN', 'Kenya', 0),
    ('KI', 'KIR', 'Kiribati', 0),
    ('KP', 'PRK', 'Korea, Democratic People''s Republic of', 0),
    ('XK', 'XKX', 'Kosovo', 0),
    ('KR', 'KOR', 'Korea, Republic of', 0),
    ('KW', 'KWT', 'Kuwait', 0),
    ('KG', 'KGZ', 'Kyrgyzstan', 0),
    ('LA', 'LAO', 'Lao People''s Democratic Republic', 0),
    ('LV', 'LVA', 'Latvia', 0),
    ('LB', 'LBN', 'Lebanon', 0),
    ('LS', 'LSO', 'Lesotho', 0),
    ('LR', 'LBR', 'Liberia', 0),
    ('LI', 'LIE', 'Liechtenstein', 0),
    ('LT', 'LTU', 'Lithuania', 0),
    ('LU', 'LUX', 'Luxembourg', 0),
    ('MO', 'MAC', 'Macao', 0),
    ('MK', 'MKD', 'North Macedonia', 0),
    ('MG', 'MDG', 'Madagascar', 0),
    ('MW', 'MWI', 'Malawi', 0),
    ('MY', 'MYS', 'Malaysia', 0),
    ('MV', 'MDV', 'Maldives', 0),
    ('ML', 'MLI', 'Mali', 0),
    ('MT', 'MLT', 'Malta', 0),
    ('MH', 'MHL', 'Marshall Islands', 0),
    ('MQ', 'MTQ', 'Martinique', 0),
    ('MR', 'MRT', 'Mauritania', 0),
    ('MU', 'MUS', 'Mauritius', 0),
    ('YT', 'MYT', 'Mayotte', 0),
    ('MX', 'MEX', 'Mexico', 0),
    ('FM', 'FSM', 'Micronesia, Federated States of', 0),
    ('MD', 'MDA', 'Moldova', 0),
    ('MC', 'MCO', 'Monaco', 0),
    ('MN', 'MNG', 'Mongolia', 0),
    ('MS', 'MSR', 'Montserrat', 0),
    ('MA', 'MAR', 'Morocco', 0),
    ('MZ', 'MOZ', 'Mozambique', 0),
    ('NA', 'NAM', 'Namibia', 0),
    ('NR', 'NRU', 'Nauru', 0),
    ('NP', 'NPL', 'Nepal', 0),
    ('NL', 'NLD', 'Netherlands', 0),
    ('AN', 'ANT', 'Netherlands Antilles', 0),
    ('NC', 'NCL', 'New Caledonia', 0),
    ('NZ', 'NZL', 'New Zealand', 0),
    ('NI', 'NIC', 'Nicaragua', 0),
    ('NE', 'NER', 'Niger', 0),
    ('NG', 'NGA', 'Nigeria', 0),
    ('NU', 'NIU', 'Niue', 0),
    ('NF', 'NFK', 'Norfolk Island', 0),
    ('MP', 'MNP', 'Northern Mariana Islands', 0),
    ('NO', 'NOR', 'Norway', 0),
    ('OM', 'OMN', 'Oman', 0),
    ('PK', 'PAK', 'Pakistan', 0),
    ('PW', 'PLW', 'Palau', 0),
    ('PA', 'PAN', 'Panama', 0),
    ('PG', 'PNG', 'Papua New Guinea', 0),
    ('PY', 'PRY', 'Paraguay', 0),
    ('PE', 'PER', 'Peru', 0),
    ('PH', 'PHL', 'Philippines', 0),
    ('PN', 'PCN', 'Pitcairn', 0),
    ('PL', 'POL', 'Poland', 0),
    ('PT', 'PRT', 'Portugal', 0),
    ('PR', 'PRI', 'Puerto Rico', 0),
    ('QA', 'QAT', 'Qatar', 0),
    ('RE', 'REU', 'Réunion', 0),
    ('RO', 'ROU', 'Romania', 0),
    ('RU', 'RUS', 'Russian Federation', 0),
    ('RW', 'RWA', 'Rwanda', 0),
    ('SM', 'SMR', 'San Marino', 0),
    ('ST', 'STP', 'Sao Tome and Principe', 0),
    ('SA', 'SAU', 'Saudi Arabia', 0),
    ('SN', 'SEN', 'Senegal', 0),
    ('SC', 'SYC', 'Seychelles', 0),
    ('SL', 'SLE', 'Sierra Leone', 0),
    ('SG', 'SGP', 'Singapore', 0),
    ('SK', 'SVK', 'Slovakia', 0),
    ('SI', 'SVN', 'Slovenia', 0),
    ('SB', 'SLB', 'Solomon Islands', 0),
    ('SO', 'SOM', 'Somalia', 0),
    ('ZA', 'ZAF', 'South Africa', 0),
    ('GS', 'SGS', 'South Georgia and the South Sandwich Islands', 0),
    ('ES', 'ESP', 'Spain', 0),
    ('LK', 'LKA', 'Sri Lanka', 0),
    ('KN', 'KNA', 'Saint Kitts and Nevis', 0),
    ('LC', 'LCA', 'Saint Lucia', 0),
    ('VC', 'VCT', 'Saint Vincent and the Grenadines', 0),
    ('PM', 'SPM', 'Saint Pierre and Miquelon', 0),
    ('SH', 'SHN', 'Saint Helena', 0),
    ('ME', 'MNE', 'Montenegro', 0),
    ('PS', 'PSE', 'Palestinian Territory, Occupied', 0),
    ('BL', 'BLM', 'Saint Barthélemy', 0),
    ('LY', 'LBY', 'Libyan Arab Jamahiriya', 0),
    ('GG', 'GGY', 'Guernsey', 0),
    ('TL', 'TLS', 'Timor-Leste', 0),
    ('UM', 'UMI', 'United States Minor Outlying Islands', 0),
    ('AX', 'ALA', 'Åland Islands', 0),
    ('MF', 'MAF', 'Saint Martin (French Part)', 0),
    ('OC', 'OC', 'Other Country', 0),
    ('BQ', 'BES', 'Bonaire, Sint Eustatius and Saba', 0),
    ('CW', 'CUW', 'Curaçao', 0),
    ('SX', 'SXM', 'Sint Maarten (Dutch Part)', 0),
    ('SS', 'SSD', 'South Sudan', 0),
    ('WS', 'WSM', 'Samoa', 0),
    ('RS', 'SRB', 'Serbia', 0),
    ('GB', 'GBR', 'United Kingdom', 0),
    ('US', 'USA', 'United States', 0),
    ('UY', 'URY', 'Uruguay', 0),
    ('UZ', 'UZB', 'Uzbekistan', 0),
    ('VU', 'VUT', 'Vanuatu', 0),
    ('VE', 'VEN', 'Venezuela', 0),
    ('VN', 'VNM', 'Vietnam', 0),
    ('VI', 'VIR', 'Virgin Islands, U.S.', 0),
    ('WF', 'WLF', 'Wallis and Futuna', 0),
    ('EH', 'ESH', 'Western Sahara', 0),
    ('YE', 'YEM', 'Yemen', 0),
    ('ZM', 'ZMB', 'Zambia', 0),
    ('ZW', 'ZWE', 'Zimbabwe', 0);

GO

-- =============================================
-- 3. Add Aliases for Edge Cases (Comprehensive List)
-- =============================================

-- Insert Aliases (IsAlias = 1)
INSERT INTO FATCA.CountryReference (ISOCode, ISOCode3, Country, IsAlias)
VALUES
    -- Africa Alias
    ('', 'AFC', 'Africa', 1),
    -- Asia Alias
    ('', 'AXA', 'Asia', 1),
    -- Australasia Alias
    ('', 'AUA', 'Australasia', 1),
    -- Europe Alias
    ('', 'EUR', 'Europe', 1),
    -- Other Alias
    ('', 'OTH', 'Other', 1),
    -- Not Resident in any country for Tax purposes
    ('', 'NFA', 'Not Resident in any country for Tax purposes', 1),
    -- International Alias
    ('', 'ZZZ', 'International', 1),
    -- Republic of Malta Alias
    ('MT', 'MLT', 'Republic of Malta', 1),
    -- Scotland Alias
    ('GB', 'GBR', 'Scotland', 1),
    -- Fiji Islands Alias
    ('FJ', 'FJI', 'Fiji Islands', 1),
    -- Russia Aliases
    ('RU', 'RUS', 'Russia', 1),
    ('RU', 'RUS', 'Russian Federation', 1),
    -- Taiwan Aliases
    ('TW', 'TWN', 'Taiwan', 1),
    ('TW', 'TWN', 'Republic of China (Taiwan)', 1),
    ('TW', 'TWN', 'Taiwan (Province of China)', 1),
    -- Bonaire Aliases
    ('BQ', 'BES', 'Bonaire', 1),
    ('BQ', 'BES', 'Sint Eustatius and Saba', 1),
    -- United States Aliases
    ('US', 'USA', 'USA', 1),
    ('US', 'USA', 'United States of America', 1),
    ('US', 'USA', 'US', 1),
    -- United Kingdom Aliases
    ('GB', 'GBR', 'UK', 1),
    ('GB', 'GBR', 'Britain', 1),
    ('GB', 'GBR', 'Great Britain', 1),
    ('GB', 'GBR', 'England', 1),
    -- South Korea Aliases
    ('KR', 'KOR', 'South Korea', 1),
    ('KR', 'KOR', 'Republic of Korea', 1),
    ('KR', 'KOR', 'Korea (South)', 1),
    -- North Korea Aliases
    ('KP', 'PRK', 'North Korea', 1),
    ('KP', 'PRK', 'Democratic People''s Republic of Korea', 1),
    ('KP', 'PRK', 'Korea (North)', 1),
    -- Iran Aliases
    ('IR', 'IRN', 'Iran', 1),
    ('IR', 'IRN', 'Islamic Republic of Iran', 1),
    -- Syria Aliases
    ('SY', 'SYR', 'Syria', 1),
    ('SY', 'SYR', 'Syrian Arab Republic', 1),
    -- Moldova Aliases
    ('MD', 'MDA', 'Moldova', 1),
    ('MD', 'MDA', 'Republic of Moldova', 1),
    ('MD', 'MDA', 'Moldova, Republic Of', 1),
    -- Czechia Aliases
    ('CZ', 'CZE', 'Czechia', 1),
    ('CZ', 'CZE', 'Czech Republic', 1),
    -- Ivory Coast Aliases
    ('CI', 'CIV', 'Ivory Coast', 1),
    ('CI', 'CIV', 'Cote dIvoire', 1),
    -- Eswatini Aliases
    ('SZ', 'SWZ', 'Eswatini', 1),
    ('SZ', 'SWZ', 'Swaziland', 1),
    -- Myanmar Aliases
    ('MM', 'MMR', 'Burma', 1),
    ('MM', 'MMR', 'Republic of the Union of Myanmar', 1),
    -- Brunei Aliases
    ('BN', 'BRN', 'Brunei', 1),
    ('BN', 'BRN', 'Brunei Darussalam', 1),
    -- Palestine Aliases
    ('PS', 'PSE', 'Palestine', 1),
    ('PS', 'PSE', 'Palestinian Territory, Occupied', 1),
    -- Kosovo Aliases
    ('XK', 'XKX', 'Kosovo', 1),
    ('XK', 'XKX', 'Republic of Kosovo', 1),
    -- Vanuatu Aliases
    ('VU', 'VUT', 'Vanuatu, Republic of', 1),
    -- Laos Aliases
    ('LA', 'LAO', 'Laos', 1),
    ('LA', 'LAO', 'Lao', 1),
    ('LA', 'LAO', 'Lao People''s Democratic Republic', 1),
    -- Micronesia Aliases
    ('FM', 'FSM', 'Micronesia', 1),
    ('FM', 'FSM', 'Federated States of Micronesia', 1),
    -- East Timor Aliases
    ('TL', 'TLS', 'East Timor', 1),
    ('TL', 'TLS', 'Timor-Leste', 1),
    -- Åland Islands Aliases
    ('AX', 'ALA', 'Aland Islands', 1),
    ('AX', 'ALA', 'Åland Islands', 1),
    -- South Sudan Aliases
    ('SS', 'SSD', 'South Sudan', 1),
    -- Svalbard and Jan Mayen Aliases
    ('SJ', 'SJM', 'Svalbard', 1),
    -- Réunion Aliases
    ('RE', 'REU', 'Reunion', 1),
    -- Holy See Aliases
    ('VA', 'VAT', 'Holy See', 1),
    ('VA', 'VAT', 'Vatican City', 1),
    ('VA', 'VAT', 'Holy See (Vatican City State)', 1),
    -- Curaçao Aliases
    ('CW', 'CUW', 'Curacao', 1),
    ('CW', 'CUW', 'Curaçao', 1),
    -- Sint Maarten Aliases
    ('SX', 'SXM', 'Sint Maarten', 1),
    ('SX', 'SXM', 'Sint Maarten (Dutch Part)', 1),
    -- Saint Martin (French Part) Aliases
    ('MF', 'MAF', 'Saint Martin', 1),
    ('MF', 'MAF', 'Saint Martin (French Part)', 1),
    -- British Virgin Islands Aliases
    ('VG', 'VGB', 'British Virgin Islands', 1),
    ('VG', 'VGB', 'Virgin Islands, British', 1),
    -- United States Virgin Islands Aliases
    ('VI', 'VIR', 'United States Virgin Islands', 1),
    ('VI', 'VIR', 'Virgin Islands, U.S.', 1),
    ('VI', 'VIR', 'Virgin Islands', 1),
    -- U.S. Minor Outlying Islands Aliases
    ('UM', 'UMI', 'U.S. Minor Outlying Islands', 1),
    ('UM', 'UMI', 'US Minor Outlying Islands', 1),
    -- British Indian Ocean Territory Aliases
    ('IO', 'IOT', 'British Indian Ocean Territory', 1),
    -- Macau Aliases
    ('MO', 'MAC', 'Macau', 1),
    ('MO', 'MAC', 'Macao', 1),
    -- Tokelau Aliases
    ('TK', 'TKL', 'Tokelau', 1),
    -- Libya Aliases
    ('LY', 'LBY', 'Libya', 1),
    ('LY', 'LBY', 'Libyan Arab Jamahiriya', 1),
    -- Congo-Kinshasa Alias
    ('CD', 'COD', 'Congo-Kinshasa', 1),
    -- Falkland Islands Alias
    ('FK', 'FLK', 'Falkland Islands', 1),
    -- Heard and McDonald Islands Alias
    ('HM', 'HMD', 'Heard and McDonald Islands', 1),
    -- Macedonia Alias
    ('MK', 'MKD', 'Macedonia', 1),
    -- United Arab Emirates Aliases
    ('AE', 'ARE', 'UAE', 1),
    ('AE', 'ARE', 'United Arab Emirates', 1),
    -- Sandwich Islands Alias
    ('GS', 'SGS', 'The Sandwich Islands', 1),
    -- Tahiti Alias
    ('PF', 'PYF', 'Tahiti', 1),
    -- Gibralta Alias
    ('GI', 'GIB', 'Gibralta', 1),
    -- FIJ Alias
    ('FJ', 'FJI', 'FIJ', 1),
    -- TGA Alias
    ('TO', 'TON', 'TGA', 1),
    -- NET Alias
    ('', 'NET', 'NET', 1),
    -- TAH Alias
    ('PF', 'PYF', 'TAH', 1),
    -- WIN Alias
    ('', 'WIN', 'West Indies', 1);

	-- =============================================
-- Add Missing Aliases to the CountryReference Table
-- =============================================
INSERT INTO FATCA.CountryReference (ISOCode, ISOCode3, Country, IsAlias)
VALUES
    -- Sweden Aliases
    ('SE', 'SWE', 'Sweden', 1),
    
    -- Switzerland Aliases
    ('CH', 'CHE', 'Switzerland', 1),
    
    -- Thailand Alias
    ('TH', 'THA', 'Thailand', 1),
    
    -- Tanzania Aliases
    ('TZ', 'TZA', 'Tanzania, United Republic Of', 1),
    ('TZ', 'TZA', 'United Republic of Tanzania', 1),
    ('TZ', 'TZA', 'Tanzania', 1),
    
    -- Uganda Alias
    ('UG', 'UGA', 'Uganda', 1),
   
    -- Côte d'Ivoire Aliases (handling typos and missing accents)
    ('CI', 'CIV', 'Cote dIivoire', 1), -- Typo version from your data
    ('CI', 'CIV', 'Cote dIvoire', 1),  -- Without accent
    ('CI', 'CIV', 'Côte dIvoire', 1),   -- Correct spelling without apostrophe
    ('CI', 'CIV', 'Côte d''Ivoire', 1), -- Correct spelling with apostrophe
    
    -- Republic of Ghana Alias
    ('GH', 'GHA', 'Republic of Ghana', 1),
    
    -- Not Res in any country for Tax purposes Alias
    ('', 'NFA', 'Not Res in any country for Tax purposes', 1),
    
    -- Sudan Alias
    ('SD', 'SDN', 'Sudan', 1),
    
    -- Svalbard And Jan Mayen Alias
    ('SJ', 'SJM', 'Svalbard And Jan Mayen', 1),
    
    -- Suriname Alias
    ('SR', 'SUR', 'Suriname', 1),
    
    -- Sweden Alias
    ('SE', 'SWE', 'Sweden', 1),
    
    -- Turks And Caicos Islands Alias
    ('TC', 'TCA', 'Turks And Caicos Islands', 1),
    
    -- Togo Alias
    ('TG', 'TGO', 'Togo', 1),
    
    -- Thailand Alias
    ('TH', 'THA', 'Thailand', 1),
    
    -- Tajikistan Alias
    ('TJ', 'TJK', 'Tajikistan', 1),
    
    -- Turkmenistan Alias
    ('TM', 'TKM', 'Turkmenistan', 1),
    
    -- Tonga Alias
    ('TO', 'TON', 'Tonga', 1),
    
    -- Trinidad and Tobago Alias
    ('TT', 'TTO', 'Trinidad and Tobago', 1),
    
    -- Tunisia Alias
    ('TN', 'TUN', 'Tunisia', 1),
    
    -- Turkey Alias
    ('TR', 'TUR', 'Turkey', 1),
    
    -- Tuvalu Alias
    ('TV', 'TUV', 'Tuvalu', 1),
    
    -- Tanzania Aliases
    ('TZ', 'TZA', 'Tanzania, United Republic Of', 1),
    ('TZ', 'TZA', 'United Republic of Tanzania', 1),
    ('TZ', 'TZA', 'Tanzania', 1),

    
    -- Ukraine Alias
    ('UA', 'UKR', 'Ukraine', 1);


-- =============================================
-- 4. Verify the Data Insertion
-- =============================================

-- This query retrieves all entries marked as aliases to ensure they are correctly inserted.
SELECT ReferenceID, ISOCode, ISOCode3, Country, IsAlias
FROM FATCA.CountryReference
WHERE IsAlias = 1
ORDER BY ISOCode, Country;

GO



-- =============================================
-- 8. Retrieve Data with ISO Codes, Handling Missing Codes and Edge Cases
-- =============================================
SELECT DISTINCT TOP 1000
    cr.[ResidentialCountry1],
    ISNULL(crf.ISOCode, 'XX') AS [Res Country Code], -- 'XX' indicates missing ISO code

    cr.[PostalCountry2],
    ISNULL(pf.ISOCode, 'XX') AS [Postal Country Code], -- 'XX' indicates missing ISO code

    cr.[CountryofBirthIdName],
    ISNULL(cb.ISOCode, 'XX') AS [Country of Birth] -- 'XX' indicates missing ISO code
FROM [SQLUAT].[DataServices].FATCA.Stage_crmdatafatcacrs_jf cr

-- Join for Residential Country using CountryReference
LEFT JOIN FATCA.CountryReference crf
    ON UPPER(crf.Country) = UPPER(LTRIM(RTRIM(cr.[ResidentialCountry1])))

-- Join for Postal Country using CountryReference
LEFT JOIN FATCA.CountryReference pf
    ON UPPER(pf.Country) = UPPER(LTRIM(RTRIM(cr.[PostalCountry2])))

-- Join for Country of Birth using CountryReference
LEFT JOIN FATCA.CountryReference cb
    ON UPPER(cb.Country) = UPPER(LTRIM(RTRIM(ISNULL(cr.[CountryofBirthIdName], ''))))

-- Optional: Filter to identify records with missing ISO codes
WHERE crf.ISOCode IS NULL
   OR pf.ISOCode IS NULL
   OR cb.ISOCode IS NULL

-- Optional: Order the results for better readability
ORDER BY cr.[ResidentialCountry1], cr.[PostalCountry2], cr.[CountryofBirthIdName];
GO

--
--missing counbtry or incoreect coutnr yname fro mCRM
--IndividualCountryJurisdictionName



--------Check the Country base CRM table

 Select distinct top  1000
 --Part one is from CRM coutnry base table
 cr.dsl_BIKey,
 cr.dsl_countryname,

 --Part 2 is from the  [SQLUAT].[DataServices].FATCA.CountryReference
 c.ISOcode,
 c.country,
 c.IsAlias

 FROM [Dynamics].[CRM_MSCRM].[dbo].[dsl_countryBase] cr
 --try to join[SQLUAT].[DataServices].FATCA.CountryReference to see if they are matching
 LEFT JOIN 
  [SQLUAT].[DataServices].FATCA.CountryReference c on c.country COLLATE DATABASE_DEFAULT = cr.[dsl_countryname] COLLATE DATABASE_DEFAULT

 where c.ISOcode = ''


--dsl_countryname from CRM these are the Edge cases
--Africa
--Australasia
--Asia
--Cote dIivoire
--Congo-Kinshasa
--Europe
--FIJ
--Falkland Islands
--Republic of Ghana
--Gibralta
--Heard and Mcdonald Islands
--Lao
--Libya
--Moldova, Republic Of
--Macedonia
--NET
--Not Res in any country for Tax purposes
--Other
--The Sandwich Islands
--Tahiti
--TGA
--UAE
--US Minor Outlying Islands
--Holy See (Vatican City State)
--Virgin Islands, British
--Virgin Islands
--West Indies
--International