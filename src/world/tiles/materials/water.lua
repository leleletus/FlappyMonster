-- Agua: la física de nado que usaba PlayerAdventure (valores efectivos).
return {
    name = 'water', label = 'Agua', liquid = true,
    gravityMult = 0.3, jumpMult = 0.75, speedMult = 0.60, drag = 3,
    drown = true, distort = true, bubbles = true,
    tint = { 0.05, 0.30, 0.90, 0.35 },
    coldTint = { 0.42, 0.74, 0.96, 0.42 },   -- (agua HELADA — Level:coldAt —: más clara, casi blanca: se ve que congela)
    splashIn = 'waterSplash', splashOut = 'waterSplashOut',
    color = { 0.20, 0.45, 0.95 },
}
