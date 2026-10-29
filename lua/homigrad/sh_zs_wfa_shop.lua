-- Оружие аддона [WFA] WarFighter's Arsenal: ZCity Weapon Pack в арсенальном ящике Zombie Survival (sh_zs_supplyboxes.lua).
-- Все стволы пака, кроме гранатометов и гранат. Цена внутри вкладки растет с уроном калибра и емкостью магазина.
-- Если аддон не установлен, его оружие просто не показывается в магазине (zs_supply_box.lua проверяет класс).
-- Вкладки: оружие из категорий пака раскладывается по вкладкам арсенала, пулеметы - новая вкладка "Machine Guns".

local wfaItems = {
	["Shotguns"] = {
		{class = "weapon_izh18", price = 350}, -- IZH-18, 12/70 gauge
		{class = "weapon_tumberahui", price = 380}, -- Tumbera, 12/70 gauge
		{class = "weapon_duplet", price = 410}, -- Sawed-off Duplet, 12/70 gauge
		{class = "weapon_dupletlong", price = 440}, -- Duplet, 12/70 gauge
		{class = "weapon_auto5", price = 470}, -- Browning Auto-5, 12/70 gauge
		{class = "weapon_ithaca37", price = 500}, -- Ithaca Model 37, 12/70 gauge
		{class = "weapon_maulshotgun", price = 540}, -- MAUL, 12/70 gauge
		{class = "weapon_revolvermts255", price = 570}, -- MTs255-12, 12/70 gauge
		{class = "weapon_saiga12spikeys", price = 600}, -- Spike X1S, 12/70 gauge
		{class = "weapon_sjirgen", price = 630}, -- Sjögren Shotgun, 12/70 gauge
		{class = "weapon_winchestersupa3", price = 660}, -- Winchester Super X3, 12/70 gauge
		{class = "weapon_moss500", price = 690}, -- Mossberg M500, 12/70 gauge
		{class = "weapon_spasik15", price = 720}, -- Franchi SPAS-15, 12/70 gauge
		{class = "weapon_maverickshot", price = 750}, -- Mossberg Maverick 88, 12/70 gauge
		{class = "weapon_toz194", price = 780}, -- TOZ-194, 12/70 gauge
		{class = "weapon_ttibenelli", price = 810}, -- JW TTI Benelli M4, 12/70 gauge
		{class = "weapon_aa12", price = 850}, -- AA-12, 12/70 gauge
		{class = "weapon_remington870oiblyat", price = 880}, -- Remington 870 Custom, 12/70 gauge
		{class = "weapon_protecta", price = 910}, -- SWD Street Sweeper, 12/70 gauge
		{class = "weapon_aa12labs", price = 940}, -- [[AA-12 Gen 2 "Labs"]], 12/70 gauge
		{class = "weapon_abzats", price = 970}, -- Abzats, 23x75 SH10
		{class = "weapon_hla_wallhshot", price = 1000}, -- O.S.I.P.B.S., Pulse Buckshot
	},
	["Assault Rifles"] = {
		{class = "weapon_abakan94", price = 900}, -- AN-94, 5.45x39 mm
		{class = "weapon_aekzaika971", price = 910}, -- AEK-971, 5.45x39 mm
		{class = "weapon_ak105d", price = 920}, -- AK-105, 5.45x39 mm
		{class = "weapon_ak12", price = 930}, -- AK-12, 5.45x39 mm
		{class = "weapon_ak12k", price = 940}, -- AK-12K, 5.45x39 mm
		{class = "weapon_ak74modern", price = 950}, -- AK-74M, 5.45x39 mm
		{class = "weapon_akalpha", price = 950}, -- Ak Alpha, 5.45x39 mm
		{class = "weapon_aksss74", price = 960}, -- AKS-74, 5.45x39 mm
		{class = "weapon_mpikm74", price = 970}, -- MPi-KM74, 5.45x39 mm
		{class = "weapon_vulkan", price = 980}, -- Malyuk, 5.45x39 mm
		{class = "weapon_aacmedovik", price = 990}, -- AAC Honey Badger, .300 AAC Blackout
		{class = "weapon_ak103d", price = 1000}, -- AK-103, 7.62x39 mm
		{class = "weapon_ak104d", price = 1010}, -- AK-104, 7.62x39 mm
		{class = "weapon_ak15", price = 1020}, -- AK-15, 7.62x39 mm
		{class = "weapon_ak15k", price = 1030}, -- AK-15K, 7.62x39 mm
		{class = "weapon_akmssss", price = 1040}, -- AKMS, 7.62x39 mm
		{class = "weapon_ark77", price = 1050}, -- ARK-77 R.I.P.R. Mk.2, 7.62x39 mm
		{class = "weapon_groza14a", price = 1050}, -- OTs-14-1A, 7.62x39 mm
		{class = "weapon_hornstg", price = 1060}, -- Großfuß SturmGewehr, 7.92x33mm Kurz
		{class = "weapon_m70", price = 1070}, -- Zastava M70, 7.62x39 mm
		{class = "weapon_m92zas", price = 1080}, -- Zastava M92, 7.62x39 mm
		{class = "weapon_mpikm", price = 1090}, -- MPi-KM, 7.62x39 mm
		{class = "weapon_qmedovik", price = 1100}, -- Q Honey Badger, .300 AAC Blackout
		{class = "weapon_rk62vel", price = 1110}, -- RK 62, 7.62x39 mm
		{class = "weapon_rk95sak", price = 1120}, -- RK 95 TP, 7.62x39 mm
		{class = "weapon_stg443", price = 1130}, -- SturmGewehr 44, 7.92x33mm Kurz
		{class = "weapon_stg4567", price = 1140}, -- SturmGewehr 45(M), 7.92x33mm Kurz
		{class = "weapon_type81ak", price = 1150}, -- Type 81 AR, 7.62x39 mm
		{class = "weapon_vg15", price = 1150}, -- Gustloff Volkssturmgewehr, 7.92x33mm Kurz
		{class = "weapon_vz58", price = 1160}, -- Sa vz. 58, 7.62x39 mm
		{class = "weapon_akmnboss", price = 1170}, -- [[AKMN "Nomad"]], 7.62x39 mm
		{class = "weapon_colt733", price = 1180}, -- Colt Model 733, 5.56x45 mm
		{class = "weapon_famasf1", price = 1190}, -- FAMAS F1, 5.56x45 mm
		{class = "weapon_ak101", price = 1200}, -- AK-101, 5.56x45 mm
		{class = "weapon_ak102", price = 1210}, -- AK-102, 5.56x45 mm
		{class = "weapon_ak19", price = 1220}, -- AK-19, 5.56x45 mm
		{class = "weapon_auga1", price = 1230}, -- AUG A1, 5.56x45 mm
		{class = "weapon_auga3", price = 1240}, -- AUG A3, 5.56x45 mm
		{class = "weapon_balashnikovgalil", price = 1250}, -- Galil AR, 5.56x45 mm
		{class = "weapon_f90ron", price = 1250}, -- F90 MBR, 5.56x45 mm
		{class = "weapon_fn2000", price = 1260}, -- FN 2000, 5.56x45 mm
		{class = "weapon_fnfnc", price = 1270}, -- FN FNC, 5.56x45 mm
		{class = "weapon_fx05", price = 1280}, -- FX-05 Xiuhcoatl, 5.56x45 mm
		{class = "weapon_g36cron", price = 1290}, -- G36C, 5.56x45 mm
		{class = "weapon_hk53", price = 1300}, -- HK53, 5.56x45 mm
		{class = "weapon_ia2", price = 1310}, -- IA2, 5.56x45 mm
		{class = "weapon_kacsr16", price = 1320}, -- SR-16, 5.56x45 mm
		{class = "weapon_krinkov556", price = 1330}, -- Soviet Arms Krink, 5.56x45 mm
		{class = "weapon_l85a2", price = 1340}, -- L85A2, 5.56x45 mm
		{class = "weapon_lr300", price = 1350}, -- LR 300, 5.56x45 mm
		{class = "weapon_m16a2manohota", price = 1350}, -- M16A3, 5.56x45 mm
		{class = "weapon_m16a4", price = 1360}, -- M16A4, 5.56x45 mm
		{class = "weapon_mk1", price = 1370}, -- CQB 11, 5.56x45 mm
		{class = "weapon_mk18", price = 1380}, -- MK 18, 5.56x45 mm
		{class = "weapon_qbz97", price = 1390}, -- QBZ-97-1, 5.56x45 mm
		{class = "weapon_remingtonacr", price = 1400}, -- ACR, 5.56x45 mm
		{class = "weapon_scarl", price = 1410}, -- SCAR-L, 5.56x45 mm
		{class = "weapon_slr15tti", price = 1420}, -- TTI SLR-15, 5.56x45 mm
		{class = "weapon_stoner63", price = 1430}, -- Stoner 63, 5.56x45 mm
		{class = "weapon_xm29oicw", price = 1440}, -- OICW, 5.56x45 mm
		{class = "weapon_mcxspear", price = 1450}, -- SIG MCX Spear, .277 Fury
		{class = "weapon_xm8", price = 1450}, -- XM8, 5.56x45 mm
		{class = "weapon_groza4", price = 1460}, -- OTs-14-4, 9x39 mm
		{class = "weapon_hla_ordrifle_type2", price = 1470}, -- O.C.I.P.R. Type 2, Pulse
		{class = "weapon_hla_ordrifle", price = 1480}, -- O.C.I.P.R., Pulse
		{class = "weapon_ak308", price = 1490}, -- AK-308, 7.62x51 mm
		{class = "weapon_ar10", price = 1500}, -- AR-10, 7.62x51 mm
		{class = "weapon_fnfal", price = 1510}, -- FN FAL, 7.62x51 mm
		{class = "weapon_fnfalpara", price = 1520}, -- FN FAL Para, 7.62x51 mm
		{class = "weapon_g3a3", price = 1530}, -- G3A3, 7.62x51 mm
		{class = "weapon_m14", price = 1540}, -- M14, 7.62x51 mm
		{class = "weapon_sa58", price = 1550}, -- SA58, 7.62x51 mm
		{class = "weapon_scarh", price = 1550}, -- SCAR-H, 7.62x51 mm
		{class = "weapon_avtsvo", price = 1560}, -- AVT-40, 7.62x54 mm
		{class = "weapon_svtsvo", price = 1570}, -- SVT-40, 7.62x54 mm
		{class = "weapon_fg42", price = 1580}, -- FG 42, 7.92x57mm Mauser
		{class = "weapon_stkb98", price = 1590}, -- Sturm-Karabiner 98 Kurz/I, 7.92x57mm Mauser
		{class = "weapon_apsunderwater", price = 1600}, -- APS, 5.66x120 Steel Darts
	},
	["Carbines"] = {
		{class = "weapon_uzicarbine", price = 450}, -- Uzi carbine, 9x19 mm Parabellum
		{class = "weapon_p320fluxchassis", price = 540}, -- Raider X P320, 9x19 mm Parabellum
		{class = "weapon_ar6951", price = 640}, -- AR-6951, 9x19 mm Parabellum
		{class = "weapon_mini30762", price = 730}, -- Mini-30, 7.62x39 mm
		{class = "weapon_mini14ranchrifle", price = 820}, -- Mini-14 Ranch Rifle, 5.56x45 mm
		{class = "weapon_adar215", price = 910}, -- ADAR 2-15, 5.56x45 mm
		{class = "weapon_coltlec", price = 1010}, -- Colt Law Enforcement Carbine, 5.56x45 mm
		{class = "weapon_rfb", price = 1100}, -- RFB, 7.62x51 mm
	},
	["Pistols"] = {
		{class = "weapon_rugermk3", price = 180}, -- Ruger MK III, .22 Long Rifle
		{class = "weapon_rugermk4", price = 190}, -- Ruger MK IV, .22 Long Rifle
		{class = "weapon_ppk", price = 200}, -- Walther PPK, 7.65x17 mm
		{class = "weapon_m70zastavapist", price = 220}, -- Zastava M70, 7.65x17 mm
		{class = "weapon_makarovpistolpb", price = 230}, -- Makarov PB, 9x18 mm
		{class = "weapon_apsss", price = 240}, -- APS, 9x18 mm
		{class = "weapon_pernachots", price = 250}, -- OTs-33 Pernach, 9x18 mm
		{class = "weapon_hkp7", price = 260}, -- P7, 9x19 mm Parabellum
		{class = "weapon_p38", price = 270}, -- Walther P38, 9x19 mm Parabellum
		{class = "weapon_minebeap220", price = 290}, -- P9, 9x19 mm Parabellum
		{class = "weapon_p220", price = 300}, -- P220, 9x19 mm Parabellum
		{class = "weapon_mauserred9", price = 310}, -- [[M1916 Prussian "Red 9"]], 9x19 mm Parabellum
		{class = "weapon_glock19gena5", price = 320}, -- Glock 19, 9x19 mm Parabellum
		{class = "weapon_m9berettacommando", price = 330}, -- [[Beretta M9 "Commando"]], 9x19 mm Parabellum
		{class = "weapon_vp9hk", price = 340}, -- HK VP9, 9x19 mm Parabellum
		{class = "weapon_p99", price = 360}, -- Walther P99, 9x19 mm Parabellum
		{class = "weapon_cz75sp01", price = 370}, -- ČZ 75 SP-01, 9x19 mm Parabellum
		{class = "weapon_p250", price = 380}, -- P250, 9x19 mm Parabellum
		{class = "weapon_swmp9", price = 390}, -- S&W M&P9, 9x19 mm Parabellum
		{class = "weapon_thebignine", price = 400}, -- The Big Nine, 9x19 mm Parabellum
		{class = "weapon_goshan18", price = 420}, -- GSh-18, 9x19 mm Parabellum
		{class = "weapon_grach", price = 430}, -- MP-443 Grach, 9x19 mm Parabellum
		{class = "weapon_m712", price = 440}, -- M712 Schnellfeuer, 9x19 mm Parabellum
		{class = "weapon_tticglock", price = 450}, -- TTI G17, 9x19 mm Parabellum
		{class = "weapon_p320alligator", price = 460}, -- [["Alligator Snapper"]], 9x19 mm Parabellum
		{class = "weapon_tti2011", price = 470}, -- TTI 2011 Combat Master, 9x19 mm Parabellum
		{class = "weapon_fivsevn", price = 490}, -- FN Five-seveN, 5.7x28 mm
		{class = "weapon_revolversw686", price = 500}, -- S&W M686, .38 Special
		{class = "weapon_revolverswr8", price = 510}, -- S&W M327 R8, .38 Special
		{class = "weapon_glock22", price = 520}, -- Glock 22, .40 SW
		{class = "weapon_mk23", price = 530}, -- MK 23, .45 ACP
		{class = "weapon_python", price = 540}, -- Colt Python, .357 Magnum
		{class = "weapon_revolver412rex", price = 560}, -- MP-412 REX, .357 Magnum
		{class = "weapon_revolvermodel29", price = 570}, -- S&W M29, .44 Remington Magnum
		{class = "weapon_conan357", price = 580}, -- Coonan .357, .357 Magnum
		{class = "weapon_grizzlymkv", price = 590}, -- Grizzly Mark V, .50 Action Express
		{class = "weapon_danish1865", price = 600}, -- Danish 1865/97 revolver, 7.62x54 mm
		{class = "weapon_magnumbfr", price = 610}, -- Magnum Research BFR, 7.62x54 mm
		{class = "weapon_revolve50bmg", price = 630}, -- Taurus Raging Balls, .50 BMG
		{class = "weapon_revolverequiem", price = 640}, -- [["Requiem"]], 12.7x55 mm
		{class = "weapon_revolversh12", price = 650}, -- RSh-12, 12.7x55 mm
	},
	["PDW"] = {
		{class = "weapon_sam180", price = 600}, -- American-180, .22 Long Rifle
		{class = "weapon_pm63rak", price = 610}, -- PM-63 RAK, 9x18 mm
		{class = "weapon_bizon", price = 620}, -- PP-19 Bizon-2, 9x18 mm
		{class = "weapon_mpi81", price = 640}, -- MPi 81, 9x19 mm Parabellum
		{class = "weapon_mp5sd", price = 650}, -- HK MP5SD, 9x19 mm Parabellum
		{class = "weapon_mx4berettastorm", price = 660}, -- SPC9, 9x19 mm Parabellum
		{class = "weapon_scorpievo3", price = 680}, -- CZ Scorpion Evo 3, 9x19 mm Parabellum
		{class = "weapon_scp9lollolo", price = 690}, -- SPC9, 9x19 mm Parabellum
		{class = "weapon_vityaz", price = 700}, -- PP-19-01 Vityaz, 9x19 mm Parabellum
		{class = "weapon_bechowiec", price = 710}, -- Bechowiec, 9x19 mm Parabellum
		{class = "weapon_blyskawichka", price = 720}, -- Błyskawica, 9x19 mm Parabellum
		{class = "weapon_m12beret", price = 740}, -- Beretta M12, 9x19 mm Parabellum
		{class = "weapon_mat49", price = 750}, -- MAT-49, 9x19 mm Parabellum
		{class = "weapon_microuzi", price = 760}, -- Micro Uzi, 9x19 mm Parabellum
		{class = "weapon_minebea", price = 780}, -- PM-9, 9x19 mm Parabellum
		{class = "weapon_miniuzi", price = 790}, -- Mini Uzi, 9x19 mm Parabellum
		{class = "weapon_mp18smg", price = 800}, -- MP 18, 9x19 mm Parabellum
		{class = "weapon_mp2ger", price = 810}, -- MP2, 9x19 mm Parabellum
		{class = "weapon_mp34smg", price = 820}, -- MP 34, 9x19 mm Parabellum
		{class = "weapon_mp40", price = 840}, -- MP40, 9x19 mm Parabellum
		{class = "weapon_mp41r", price = 850}, -- MP 41(r), 9x19 mm Parabellum
		{class = "weapon_mpl", price = 860}, -- Walther MPL, 9x19 mm Parabellum
		{class = "weapon_stenmk2", price = 880}, -- Sten SMG Mk II, 9x19 mm Parabellum
		{class = "weapon_stenmk5", price = 890}, -- Sten SMG Mk V, 9x19 mm Parabellum
		{class = "weapon_sterling", price = 900}, -- Sterling SMG, 9x19 mm Parabellum
		{class = "weapon_armaguera", price = 910}, -- Armaguerra OG-43, 9x19 mm Parabellum
		{class = "weapon_kp31", price = 920}, -- Suomi KP/-31, 9x19 mm Parabellum
		{class = "weapon_ar5767", price = 940}, -- AR-57, 5.7x28 mm
		{class = "weapon_devochkaump", price = 950}, -- HK UMP45, .45 ACP
		{class = "weapon_m3greasegun", price = 960}, -- M3 Grease Gun, .45 ACP
		{class = "weapon_mp510mm", price = 980}, -- HK MP5/10, 10mm Auto
		{class = "weapon_thompson", price = 990}, -- Thompson M1A1, .45 ACP
		{class = "weapon_thompsonm1928", price = 1000}, -- Thompson M1928A1, .45 ACP
		{class = "weapon_type79smg", price = 1010}, -- Type 79 SMG, 7.62x25 mm
		{class = "weapon_ppk42", price = 1020}, -- PPK-42, 7.62x25 mm
		{class = "weapon_pps", price = 1040}, -- PPS-43, 7.62x25 mm
		{class = "weapon_ppsh", price = 1050}, -- PPSH-41, 7.62x25 mm
		{class = "weapon_ppd", price = 1060}, -- PPD-40, 7.62x25 mm
		{class = "weapon_ppshboss", price = 1080}, -- [[PPSH-41 "Raider"]], 7.62x25 mm
		{class = "weapon_ublydok", price = 1090}, -- Bastard, 5.45x39 mm
		{class = "weapon_hla_gruntsmg", price = 1100}, -- O.S.I.P.S., Pulse
	},
	["Marksman Rifles"] = {
		{class = "weapon_tranqrifle", price = 1200}, -- Tranquilizer Rifle, Tranquilizer Darts
		{class = "weapon_yellowboy", price = 1240}, -- Winchester Model 1866, .38 Special
		{class = "weapon_delisle", price = 1270}, -- De Lisle Carbine, .45 ACP
		{class = "weapon_vss", price = 1310}, -- VSS Vintorez, 9x39 mm
		{class = "weapon_m24remington", price = 1340}, -- M24, 7.62x51 mm
		{class = "weapon_walther2000w", price = 1380}, -- Walther WA 2000, 7.62x51 mm
		{class = "weapon_m1garand", price = 1410}, -- Mk 2 Mod 1, 7.62x51 mm
		{class = "weapon_cs5", price = 1450}, -- McMillan CS5, 7.62x51 mm
		{class = "weapon_l42a1", price = 1490}, -- Enfield Enforcer, 7.62x51 mm
		{class = "weapon_psg1", price = 1520}, -- PSG1, 7.62x51 mm
		{class = "weapon_scarssr", price = 1560}, -- SCAR SSR, 7.62x51 mm
		{class = "weapon_m14dmr", price = 1590}, -- M14 DMR, 7.62x51 mm
		{class = "weapon_mp18", price = 1630}, -- MP-18, 7.62x54 mm
		{class = "weapon_mosinm9130", price = 1660}, -- Mosin-Nagant M91/30, 7.62x54 mm
		{class = "weapon_winchesterm1984", price = 1700}, -- Winchester Model 1895, 7.62x54 mm
		{class = "weapon_svds", price = 1740}, -- SVDS, 7.62x54 mm
		{class = "weapon_svo98", price = 1770}, -- SV-98, 7.62x54 mm
		{class = "weapon_kar98kriegsmod", price = 1810}, -- Karabiner 98k Kriegsmodell, 7.92x57mm Mauser
		{class = "weapon_gewehr43", price = 1840}, -- Gewehr 43, 7.92x57mm Mauser
		{class = "weapon_barret82", price = 1880}, -- Barrett M82, .50 BMG
		{class = "weapon_zastavam93", price = 1910}, -- Zastava M93 Black Arrow, .50 BMG
		{class = "weapon_ksvk", price = 1950}, -- KSVK 12.7, 12.7x108 mm
		{class = "weapon_dsr1", price = 1990}, -- AMP DSR-1, .338 Lapua Magnum
		{class = "weapon_t5000", price = 2020}, -- T-5000, .338 Lapua Magnum
		{class = "weapon_sakosnip", price = 2060}, -- TRG M10, .338 Lapua Magnum
		{class = "weapon_mjolnirmk18", price = 2090}, -- Mk 18 Mod 1 Mjolnir, .338 Lapua Magnum
		{class = "weapon_tkpdbear", price = 2130}, -- TKPD, 9.3x64mm Brenneke
		{class = "weapon_gaussssrifffle", price = 2160}, -- Item 62, Gauss
		{class = "weapon_ptrs", price = 2200}, -- PTRS-41, 14.5x114mm B32
	},
	["Machine Guns"] = {
		{class = "weapon_rpk74m", price = 1600}, -- RPK-74M, 5.45x39 mm
		{class = "weapon_rpk16", price = 1650}, -- RPK-16, 5.45x39 mm
		{class = "weapon_rpk762", price = 1690}, -- RPK, 7.62x39 mm
		{class = "weapon_rpd", price = 1740}, -- RPD, 7.62x39 mm
		{class = "weapon_cetmeameli", price = 1780}, -- CETME Ameli, 5.56x45 mm
		{class = "weapon_mg36", price = 1830}, -- MG36, 5.56x45 mm
		{class = "weapon_minimi", price = 1870}, -- FN Minimi, 5.56x45 mm
		{class = "weapon_stonerlmg", price = 1920}, -- Stoner 63 Commando, 5.56x45 mm
		{class = "weapon_stonerlmgchainsaw", price = 1960}, -- KAC ChainSAW, 5.56x45 mm
		{class = "weapon_hla_suppmg", price = 2010}, -- O.S.I.P.M.G., Pulse
		{class = "weapon_fnmodeld", price = 2050}, -- FN Model D, 7.62x51 mm
		{class = "weapon_hk11lmg", price = 2100}, -- HK11, 7.62x51 mm
		{class = "weapon_m60e621", price = 2150}, -- M60E6, 7.62x51 mm
		{class = "weapon_m134minigun", price = 2190}, -- M134 Minigun, 7.62x51 mm
		{class = "weapon_dp27", price = 2240}, -- DP-27, 7.62x54 mm
		{class = "weapon_pechenka", price = 2280}, -- PKP Pecheneg, 7.62x54 mm
		{class = "weapon_lapti26", price = 2330}, -- LS/26, 7.92x57mm Mauser
		{class = "weapon_wz28lmg", price = 2370}, -- Rkm wz. 28, 7.92x57mm Mauser
		{class = "weapon_madguylmg", price = 2420}, -- Madsen machine gun, 7.92x57mm Mauser
		{class = "weapon_mg34", price = 2460}, -- MG 34, 7.92x57mm Mauser
		{class = "weapon_mg42", price = 2510}, -- MG 42, 7.92x57mm Mauser
		{class = "weapon_dshk", price = 2550}, -- DShK, 12.7x108 mm
		{class = "weapon_mg338", price = 2600}, -- SIG Sauer MMG 338, .338 Norma Magnum
	},
	["Special"] = {
		{class = "weapon_nailgun", price = 300}, -- Nailgun
		{class = "weapon_crossbowowo", price = 450}, -- Crossbow
		{class = "weapon_helsing", price = 700}, -- Helsing
		{class = "weapon_flamezsisi", price = 1500}, -- Flamethrower
	},
	["Melee"] = {
		{class = "weapon_hg_can", price = 40}, -- Metal Can, none
		{class = "weapon_hg_vilka", price = 60}, -- Fork, none
		{class = "weapon_ssdagger", price = 80}, -- SS-Ehrendolch, none
		{class = "weapon_tomahawkasspocket", price = 100}, -- Pocket Tomahawk, none
	},
}

ZS_MG_AMMO_PRICE = 110 -- патроны к пулеметам (вкладка Machine Guns)

if ZS_SHOPS and ZS_SHOPS.arsenal then
	local arsenal = ZS_SHOPS.arsenal

	local function FindTab(name)
		for i, cat in ipairs(arsenal) do
			if cat.name == name then return cat, i end
		end
	end

	-- новая вкладка пулеметов - после снайперских винтовок
	if not FindTab("Machine Guns") then
		local _, marksmanIndex = FindTab("Marksman Rifles")
		table.insert(arsenal, (marksmanIndex or #arsenal) + 1, {name = "Machine Guns", ammoPrice = ZS_MG_AMMO_PRICE, items = {}})
	end

	for tabName, items in pairs(wfaItems) do
		local tab = FindTab(tabName)

		if tab then
			local known = {}
			for _, item in ipairs(tab.items) do known[item.id or item.class] = true end

			for _, item in ipairs(items) do
				if not known[item.class] then
					item.id = item.class
					item.kind = "weapon"
					item.wfa = true
					tab.items[#tab.items + 1] = item
				end
			end

			-- внутри вкладки цена растет слева направо
			table.sort(tab.items, function(a, b)
				if (a.price or 0) ~= (b.price or 0) then return (a.price or 0) < (b.price or 0) end
				return (a.id or "") < (b.id or "")
			end)
		end
	end
end
