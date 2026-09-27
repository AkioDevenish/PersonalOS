/**
 * What people actually cook at home, written down rather than recalled.
 *
 * The app used to ask the model on the phone to name a country's everyday
 * food. Asked for twenty dishes from Trinidad it produced ackee and saltfish
 * (Jamaican), rice and peas (Jamaican), bunny chow (South African) and fish
 * and chips, with no doubles, roti or pelau. Asked about Angola it knew caldo
 * verde and moqueca — Portuguese and Brazilian — and padded to twenty by
 * cross-producting them with four proteins: caldo verde de peixe, caldo verde
 * de frango, moqueca de peixe, and so on down the list.
 *
 * That is not a prompt that needs sharpening. Recalling a small country's
 * everyday food is the task the model is worst at, and asking for a fixed
 * count makes it worse, because a model that knows two dishes and is asked for
 * twenty will invent eighteen rather than stop.
 *
 * So the countries below are written out. Where a list exists it is used and
 * the model is never asked; where one does not, the model still seeds, and
 * people's votes still outrank whatever it produces. Adding a country here is
 * better than any prompt, and the list improves by someone who eats there
 * editing this file.
 *
 * Everyday home food, in the name and spelling used there — not restaurant or
 * festival food, and not what a tourist board would put on a poster.
 */
export const CURATED: Record<string, string[]> = {
  // Caribbean
  TT: [
    "Doubles", "Roti", "Buss up shut", "Bake and shark", "Pelau", "Callaloo",
    "Macaroni pie", "Curry duck", "Curry chicken", "Stew chicken", "Aloo pie",
    "Pholourie", "Corn soup", "Oil down", "Coo coo", "Saheena", "Souse",
    "Fry bake and saltfish", "Crab and dumpling", "Black pudding",
  ],
  JM: [
    "Ackee and saltfish", "Rice and peas", "Brown stew chicken", "Curry goat",
    "Jerk chicken", "Escovitch fish", "Oxtail", "Callaloo", "Fried dumplings",
    "Festival", "Bammy", "Steamed fish", "Mannish water", "Stew peas",
  ],
  GY: [
    "Pepperpot", "Cook-up rice", "Metemgee", "Curry chicken", "Roti",
    "Garlic pork", "Dhal and rice", "Bake and saltfish", "Pholourie", "Chow mein",
  ],
  BB: [
    "Cou-cou and flying fish", "Macaroni pie", "Pudding and souse", "Fish cakes",
    "Rice and peas", "Bajan fried chicken", "Bakes", "Sweet bread",
  ],

  // Africa
  NG: [
    "Jollof rice", "Egusi soup", "Pounded yam", "Efo riro", "Moi moi", "Akara",
    "Ogbono soup", "Pepper soup", "Amala", "Eba", "Okra soup", "Suya",
    "Beans and plantain", "Fried rice",
  ],
  GH: [
    "Waakye", "Banku", "Fufu", "Jollof rice", "Kenkey", "Light soup",
    "Groundnut soup", "Red red", "Kelewele", "Tuo zaafi",
  ],
  AO: [
    "Funge", "Muamba de galinha", "Calulu", "Mufete", "Kizaka",
    "Feijão de óleo de palma", "Cabidela", "Moamba de ginguba", "Pirão",
  ],
  ZA: [
    "Pap and wors", "Chakalaka", "Bobotie", "Samp and beans", "Potjiekos",
    "Bunny chow", "Vetkoek", "Umngqusho", "Boerewors", "Braai",
  ],
  KE: [
    "Ugali", "Sukuma wiki", "Nyama choma", "Githeri", "Chapati", "Pilau",
    "Mukimo", "Irio", "Kachumbari", "Mandazi",
  ],
  ET: [
    "Injera", "Doro wat", "Shiro", "Misir wat", "Gomen", "Tibs", "Kitfo",
    "Fir fir", "Atkilt wat", "Beyaynetu",
  ],
  EG: [
    "Koshari", "Ful medames", "Ta'ameya", "Molokhia", "Mahshi", "Bamia",
    "Fattah", "Roz bel laban", "Besarah",
  ],
  MA: [
    "Tagine", "Couscous", "Harira", "Rfissa", "Bissara", "Zaalouk",
    "Loubia", "Msemen", "Chermoula",
  ],

  // South Asia
  IN: [
    "Dal", "Roti", "Sabzi", "Rajma chawal", "Chole", "Khichdi", "Poha",
    "Upma", "Idli", "Dosa", "Sambar", "Curd rice", "Paratha", "Biryani",
    "Pav bhaji", "Aloo gobi",
  ],
  PK: [
    "Daal chawal", "Roti", "Aloo gosht", "Karahi", "Biryani", "Nihari",
    "Haleem", "Chana chaat", "Saag", "Paratha",
  ],
  BD: [
    "Bhat", "Daal", "Machher jhol", "Bhorta", "Khichuri", "Biryani",
    "Shorshe ilish", "Beef bhuna", "Panta bhat", "Shutki",
  ],

  // East and Southeast Asia
  CN: [
    "Fried rice", "Congee", "Tomato and egg stir-fry", "Mapo tofu",
    "Hongshao rou", "Dumplings", "Noodle soup", "Stir-fried greens",
    "Steamed fish", "Baozi",
  ],
  JP: [
    "Miso soup", "Curry rice", "Tamagoyaki", "Nikujaga", "Oyakodon",
    "Grilled salmon", "Onigiri", "Tonkatsu", "Ramen", "Udon", "Natto",
  ],
  KR: [
    "Kimchi jjigae", "Doenjang jjigae", "Bibimbap", "Bulgogi", "Japchae",
    "Sundubu jjigae", "Tteokbokki", "Galbi jjim", "Samgyetang", "Kimchi",
  ],
  TH: [
    "Pad krapow", "Tom yum", "Som tam", "Khao pad", "Green curry",
    "Tom kha gai", "Khao man gai", "Larb", "Massaman curry", "Pad thai",
  ],
  VN: [
    "Phở", "Cơm tấm", "Bún chả", "Canh chua", "Thịt kho", "Cá kho tộ",
    "Bánh mì", "Gỏi cuốn", "Bún bò Huế", "Rau muống xào",
  ],
  PH: [
    "Adobo", "Sinigang", "Tinola", "Pancit", "Lumpia", "Kare-kare",
    "Menudo", "Bicol express", "Arroz caldo", "Longganisa",
  ],
  ID: [
    "Nasi goreng", "Soto ayam", "Gado-gado", "Rendang", "Sate", "Sayur asem",
    "Tempe goreng", "Bakso", "Mie goreng", "Pecel lele",
  ],

  // Europe
  GB: [
    "Shepherd's pie", "Sunday roast", "Bangers and mash", "Fish and chips",
    "Full English breakfast", "Beans on toast", "Cottage pie", "Jacket potato",
    "Toad in the hole", "Spaghetti bolognese",
  ],
  IE: [
    "Irish stew", "Bacon and cabbage", "Colcannon", "Coddle", "Shepherd's pie",
    "Boxty", "Soda bread", "Fry-up",
  ],
  FR: [
    "Steak frites", "Poulet rôti", "Ratatouille", "Gratin dauphinois",
    "Quiche lorraine", "Blanquette de veau", "Soupe à l'oignon",
    "Croque monsieur", "Salade niçoise", "Bœuf bourguignon",
  ],
  IT: [
    "Pasta al pomodoro", "Pasta e fagioli", "Risotto", "Minestrone",
    "Ragù alla bolognese", "Carbonara", "Cotoletta", "Frittata", "Polenta",
    "Insalata caprese",
  ],
  ES: [
    "Tortilla española", "Lentejas", "Cocido", "Paella", "Gazpacho", "Pisto",
    "Pollo al ajillo", "Croquetas", "Fabada", "Ensaladilla rusa",
  ],
  PT: [
    "Bacalhau à Brás", "Caldo verde", "Cozido à portuguesa", "Bifanas",
    "Arroz de pato", "Feijoada", "Sardinhas assadas", "Sopa de legumes",
    "Massada de peixe",
  ],
  DE: [
    "Kartoffelsalat", "Schnitzel", "Bratwurst", "Rouladen", "Eintopf",
    "Käsespätzle", "Frikadellen", "Gulasch", "Sauerbraten", "Currywurst",
  ],
  GR: [
    "Fasolada", "Gemista", "Moussaka", "Pastitsio", "Briam", "Gigantes",
    "Souvlaki", "Horiatiki", "Spanakopita", "Avgolemono",
  ],
  TR: [
    "Mercimek çorbası", "Kuru fasulye", "Menemen", "Pilav", "Karnıyarık",
    "Mantı", "İmam bayıldı", "Köfte", "Dolma", "Lahmacun",
  ],
  PL: [
    "Pierogi", "Bigos", "Kotlet schabowy", "Żurek", "Rosół", "Gołąbki",
    "Placki ziemniaczane", "Barszcz", "Mizeria",
  ],

  // Americas
  US: [
    "Mac and cheese", "Chili", "Meatloaf", "Grilled cheese", "Pot roast",
    "Fried chicken", "Pancakes", "Burgers", "Chicken noodle soup", "BLT",
    "Tuna casserole", "Sloppy joes",
  ],
  CA: [
    "Poutine", "Tourtière", "Pea soup", "Butter tarts", "Montreal bagels",
    "Pancakes with maple syrup", "Shepherd's pie", "Salmon",
  ],
  MX: [
    "Tacos", "Frijoles", "Chilaquiles", "Quesadillas", "Sopa de fideo",
    "Arroz rojo", "Caldo de pollo", "Pozole", "Enchiladas", "Huevos rancheros",
    "Tamales", "Mole",
  ],
  BR: [
    "Arroz e feijão", "Feijoada", "Farofa", "Frango grelhado", "Strogonoff",
    "Bife acebolado", "Moqueca", "Pão de queijo", "Virado à paulista", "Coxinha",
  ],
  AR: [
    "Milanesa", "Asado", "Empanadas", "Guiso de lentejas", "Puchero",
    "Tarta de verduras", "Locro", "Fideos con tuco", "Pastel de papa",
  ],
  CO: [
    "Bandeja paisa", "Ajiaco", "Sancocho", "Arepas", "Frijoles",
    "Arroz con pollo", "Changua", "Calentado", "Sudado de pollo",
  ],
  PE: [
    "Lomo saltado", "Ají de gallina", "Arroz con pollo", "Causa",
    "Papa a la huancaína", "Ceviche", "Seco de res", "Tallarín saltado",
    "Sopa a la minuta",
  ],

  // Oceania
  AU: [
    "Meat pie", "Sausage sizzle", "Roast lamb", "Barbecue", "Fish and chips",
    "Spaghetti bolognese", "Vegemite on toast", "Pavlova",
  ],
}

/** The everyday dishes written down for a country, or nothing. */
export function curatedFor(country: string): string[] {
  return CURATED[country.toUpperCase()] ?? []
}
