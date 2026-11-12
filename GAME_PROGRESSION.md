# AFC Shop: progression and feature hierarchy

This is the design source of truth for the player's route through the shop. New
features should extend this sequence rather than appearing as unrelated
upgrades. The player should always have a clear next action, while the
footprints, customer demand, and earned cash gently guide them to the next tier.

## Design principles

1. **One new idea at a time.** Teach the chicken service loop before adding
   staffing, additional dining, or a new product category.
2. **Show the next goal in the world.** Use a visible, initially locked
   footprint and a short requirement label; avoid presenting every future
   system as an active button at the start.
3. **Make purchases intentional.** Each table or machine has its own cost,
   loading pad, and completion animation. Paying for one object must never
   create several.
4. **Gate by both capability and affordability.** A milestone can require a
   completed predecessor, a minimum number of sales, and enough cash.
5. **Teach products visually.** A player should be able to identify a machine's
   input, process, and output from its silhouette, labels, lighting, and visible
   product—not just from a tooltip.
6. **Keep the economy auditable.** Show costs in-world and calculate milestone
   budgets from purchase costs and conservative base sales. Do not rely on tips
   or staff income to make a required purchase possible.
7. **Preserve saves.** Any new paid progress, inventory, unlock, or owned
   machine needs a save key and a safe default for existing saves.

## Player progression

| Tier | Player experience and gate | Current/proposed economy | What the player learns |
|---|---|---:|---|
| 0. Buy the shop | Start outside. The deed pad is the only actionable purchase. | Shop: **$19,500** from **$20,000**; leaves **$500**. | The shop is the long-term goal; walking onto a pad loads money. |
| 1. Build the starter kitchen | Buy the rotary chicken fryer, then the hen hut, then one dining table. Each is a separate pad. | Fryer **$150** + hut **$200** + first table **$100** = **$450**; leaves **$50**. | A machine must be built before its supply source and customer service can form a loop. |
| 2. Serve the first customers | Collect raw chicken, load and use the fryer, collect cooked chicken, stage the order, serve the arriving customer, then collect payment and clear the table. | Base bucket price **$18** per sale. The planned table unlock assumes three bucket sales: $50 + (3 × $18) = **$104** before other spending. | The complete earn-and-reinvest loop; sequential service and cleanup. |
| 3. Grow dining from Basic to Standard | The second table footprint stays locked until **3 bucket sales and $100 available**. Each later table is purchased separately. The HR office unlocks only after all four tables are built. | Four tables: **4 × $100 = $400** total. HR office: **$200**. | More capacity is earned from customer demand, not granted all at once. |
| 4. Recruit the first team | Recruit at the HR office. The first two roles are counter crew and chicken cook. | First hire **$32**; second hire **$120**; two hires total **$152**. | Staff are a progression reward, not a prerequisite for the first sale. |
| 5. Add the fries conveyor | After the second hire, reveal the separate fries-conveyor footprint. The machine is purchased, not spawned for free. | Current implementation value: **$350**. | A new food line and clearer kitchen production equipment. |
| 6. Extend the kitchen for drinks | **Planned, not implemented.** Require four tables, the HR office, two hires, the fries conveyor, at least **60 completed sales**, and **$850 available** before showing the extension as ready to fund. Show both unmet requirements on its footprint. | Proposed only: extension **$500**, juice dispenser **$300**, opening stock/cups **$50**; total **$850**. Recalculate before implementation. | A second product category, drink selection, and a larger customer order. |
| 7. Introduce the VIP customer | **Planned, not implemented.** After **10 completed juice orders**, introduce a VIP with a chicken-and-juice combo. Make the first VIP visit a guaranteed tutorial encounter; decide the repeat rate after balancing. | Proposed first VIP combo: **$30 sale + $8 tip**. These values are not in code and need play-testing. | A special customer type, a combined order, and a visible reward for mastering the new product. |
| 8. Develop the expanded shop | **Future.** Add drink upsells/bundles, more staff roles, and later shop upgrades only after juice and VIP orders are readable and balanced. | Costs and revenue are intentionally undecided. | Long-term goals without overwhelming the starter game. |

### Conservative affordability calculation

Through the fries machine, the planned core purchases are:

```text
Fryer                         $150
Hen hut                       $200
Four separate tables          $400
HR office                     $200
First two workers             $152
Fries conveyor                $350
                              ----
Total purchases             $1,452
Shop-purchase remainder       $500
Required base-sale revenue    $952
Base meal price                 $18
ceil($952 / $18)                 53 bucket sales
```

This is a full-route upper-level budget, not a demand that the player wait for
53 bucket sales before doing anything: later purchases unlock in smaller steps. After
the first table, three bucket sales yield $54 and raise the planned $50 balance to
$104, enough to unlock the next $100 table. The budget excludes the **$4 tip**,
optional chicken-crate purchases, and any staff income; these should be treated
as bonuses, not required funding. The live hen-hut flow supplies seven chickens
per collection. The current staff-income code is gated by
`BUILD_INTERIOR_CONTENT`, which is false in the current game, so do not count
that income in progression math.

With the proposed $850 beverage expansion, cumulative purchases become
$2,302. After the initial $500 shop remainder, the conservative base-sale
shortfall is $1,802, or **101 total $18 sales**. This assumes all sales use the
current chicken-meal price and excludes tips, so it is a safe upper-bound
estimate rather than a prediction of actual play time. The 60-sale milestone
is a product-mastery gate; the $850 wallet requirement remains the actual
affordability gate. If that projected grind is too long in play, lower
expansion costs or add drink revenue after launch rather than weakening the
starter progression.

The juice expansion should be re-budgeted against actual play time and customer
revenue before its proposed prices become constants. If the expansion feels
like a grind, prefer a meaningful drink-sale revenue contribution or a lower
extension price over silently granting cash.

The proposed VIP reward is deliberately excluded from all affordability
calculations: ordinary chicken and juice sales must be sufficient to progress.

## Juice expansion concept

The reference image communicates a multi-flavor drink dispenser: a strong
header sign, distinct flavor buttons/nozzles, visible dispensing area, and a
drip tray. Use those readability cues, but create original AFC art and flavor
labels rather than copying the reference's brand names or artwork.

Recommended first juice station:

- A compact, brightly lit dispenser with four clearly named flavors (for
  example orange, mango, berry, and lemon).
- Large original flavor labels/icons above matching buttons; no tiny text as
  the only way to distinguish flavors.
- A transparent or open serving bay where the cup, colored juice, and pouring
  stream can be seen.
- A labeled fruit/syrup input and an obvious output cup, so players understand
  what is inside and what the machine produces.
- A separate kitchen extension footprint, then a separate juice-machine
  footprint; do not make extension payment silently buy the machine too.
- An introductory order that asks the player to make one juice, then a later
  order that combines chicken and juice. Keep chicken orders available so the
  new system extends rather than replaces the original loop.

The reference represents a beverage dispenser, while the requested product is
juice. The game version should make that distinction explicit with fruit
visuals and juice names; a generic soda-looking machine would not teach the
player what product it sells.

## VIP customer

The new reference is visual direction for a **special guest**, not a ready-made
game asset. It shows a friendly blocky person with a broad light-colored hat,
a bright gold feather/decoration, a white-and-gold outfit, gold waist detail,
and dark boots. Create an original AFC character using these readable silhouette
and color cues; do not copy the screenshot character or its exact model,
texture, or artwork.

### Intended player experience

1. Do not show the VIP during the opening or the first chicken-only tutorial.
2. First teach the juice station and ordinary juice orders.
3. After **10 completed juice orders**, announce that a VIP guest is expected.
   The next suitable arrival becomes a clear, one-time tutorial encounter.
4. The VIP joins the **end of the normal FIFO queue**. It never jumps ahead of
   an existing customer or prevents ordinary customers from being served.
5. Show a large, plain-language order card: **CHICKEN + [JUICE FLAVOR]**. The
   player must prepare the requested drink as well as the chicken order.
6. Show the tray and cup contents clearly at handoff. On success, play a brief,
   distinctive arrival/payment animation and explain the premium reward.
7. If a required product is unavailable, state what is missing. Do not silently
   substitute a flavor, consume nonexistent stock, or grant the reward.
8. The first visit is guaranteed when unlocked. Choose a repeat-visit rate only
   after the first experience is tested; VIP rewards must not fund required
   progression purchases.

### Visual recognition

- Use the game's blocky character proportions, but make an original silhouette:
  broad-brim light hat, small gold feather ornament, white upper clothing with
  gold trim, gold skirt/coat panels or equivalent, gold belt clasp, and dark
  boots.
- Add a subtle gold VIP badge with a dark outline above the head and on the
  order card. Keep it separate from the existing customer wait emoji so it
  remains readable and does not cover the face.
- Keep the costume high-contrast against the night road, entrance, queue, and
  interior. The face and order should remain clear from the normal gameplay
  camera; do not rely on tiny details.
- Communicate VIP status consistently in three places: character marker,
  order card, and a short toast/tutorial message. Color alone is insufficient.

### VIP order and economy rules (proposed)

- The first VIP requests one ordinary chicken meal and one selected juice.
- Proposed reward: **$30 sale + $8 tip**, replacing the ordinary chicken sale
  and tip for that visit. Do not also grant the ordinary reward.
- Grant payment once, after successful completion. Repeated service steps,
  save/reload, or interrupted animations must never duplicate payment.
- Keep ordinary rewards at **$18 sale + $4 tip**. If VIP values become live,
  store them as clearly named values rather than scattering literals.
- Compare the proposed VIP total (**$38**) with ordinary total (**$22**) during
  balancing and confirm that it cannot bypass the kitchen-extension purchase.
- Save the completed-juice-order milestone and whether the guaranteed
  introductory VIP has been introduced. Reloading must not replay the intro or
  duplicate a reward.

## Feature hierarchy and implementation handoff

Current gameplay/progression is concentrated in
[`scripts/game.gd`](./scripts/game.gd). Reusable fryer and table geometry live
in [`scripts/objects/rotary_fryer.gd`](./scripts/objects/rotary_fryer.gd) and
[`scripts/objects/dining_table.gd`](./scripts/objects/dining_table.gd). Keep
future drink-specific production and visuals in a focused object script rather
than further growing the main controller.

The current customer code cycles animal profiles from `CUSTOMER_ANIMALS`.
`_start_next_customer` assigns the active ticket and `_build_customer` creates
its visuals; `_complete_customer_payment` handles the ordinary payout. Only
one customer is spawned at a time; automatic queue NPCs are intentionally
disabled. VIP needs explicit ticket data and an explicit order kind; do not
overload `customer_species_index` or identify VIPs using a magic ticket number.

When implementing a new tier:

1. Add its prerequisite, cost, and position to this progression document and
   calculate the lowest-cost route from the current wallet.
2. Add one visible footprint with a truthful locked/unlocked state, a cost, a
   progress indicator, and an explanation of the next unmet requirement.
3. Add exactly one purchase completion, an explicit owned state, and a clear
   completion message.
4. Add the full gameplay loop: input/supply, player or worker action, produced
   item, customer order, payment, and any restocking cost.
5. Make the product visible at each important stage. From the normal gameplay
   camera, check the machine silhouette, labels, input, processing area, and
   finished product for occlusion and contrast.
6. Persist purchase progress, ownership, inventory, and unlock state. Existing
   saves should load without losing the shop or gaining a free upgrade.
7. Update the HUD/tutorial and this document together. Keep the starter loop
   playable if the player postpones the new feature.
8. Recalculate the total budget and document assumptions whenever a price,
   sale value, supply quantity, or unlock threshold changes.
9. For special customers, store customer tier, order contents, and payment
   state with that ticket. Preserve FIFO, show the same status in world and UI,
   and make rewards idempotent across saves and animations.

## Current implementation notes

- **Implemented:** shop purchase, fryer/hen-hut/first-table starter path,
  customer chicken service, individually funded dining tables, 3-sale/$100
  standard-table gate, HR office after four tables, and hiring.
- **Implemented, visuals only:** the $350 fries conveyor unlocks after two
  hires, and the rotary mill has visible hot oil/chicken during processing.
  Fries do not yet enter the order, inventory, or revenue systems.
- **Design only:** kitchen extension, juice supply/production/sales, and VIP
  customer orders/rewards. Their thresholds and costs in this guide are
  proposals, not live game settings.
- **Position update:** the billing counter is at `(4.6, 0.18, -9.3)`, moved
  5 world units forward from its previous rear position. The blue work tile,
  and customer stand are derived from that counter.
- The game uses a single progression controller in `scripts/game.gd`; purchase
  pads load cash in increments and spawn their object when fully funded.
- The starter sequence is fryer → hen hut → first table → customer service.
- Tables 2–4 require three bucket sales and at least $100 in the wallet; the HR office
  requires four tables. They form a compact 2×2 layout, with table 2 placed on
  the screen-bottom side of table 1; the next table's footprint remains hidden
  until its sale and cash requirements are met. Only unlocked, unbuilt purchase
  pads are shown.
- Hire prices are **$32, $120, $300, and $650** in role order.
- The fries conveyor is currently specified at **$350**, unlocked at two hires.
  Its machine model uses a simple mint tunnel, lit conveyor, moving fries
  cartons, and a finished carton. Decorative steam, roof vents, and extra
  product plaques were removed to keep the machine silhouette readable. It is
  a visual machine for now; it does not yet add a fries inventory item or
  change customer orders/revenue.
- The rotary fryer still performs the existing timed chicken production and
  conveyor output. Its attached spinning mill now shows a tinted viewing
  window, golden oil, bubbling motion, and chicken pieces while raw stock is
  being processed. The oil effect is visual only; there is no separate oil
  inventory or oil-consumption mechanic.
- The beverage extension and juice sales loop are design proposals only. Their
  prices, inventory rules, order mix, and revenue need balancing before coding.
- The VIP is a design proposal only. The current roster cycles through animal
  profiles; there is no VIP tier, juice-order milestone, VIP order card, or
  premium payment path yet. Implement and balance the juice loop first, then
  add a VIP ticket/profile without disrupting ordinary queue or save behavior.
- Starter customer flow spawns one customer at a time. No additional queue
  NPCs appear by default; the next customer enters after the previous one leaves.
  Each arriving customer reserves a randomly selected available seat. The
  overhead badge shows a clock while waiting and a smiling face while eating.
- The exterior customer order is one to three buckets, chosen per ticket.
  Each staged AFC carton is handed over individually; the bucket count drops
  after each completed handoff, and the customer waits at the counter for any
  remaining buckets before heading to the reserved seat. The owner can bill at
  the marked counter spot. After hiring counter crew, that worker bills
  automatically while the owner is away. A clock appears after ten seconds of
  waiting and cycles three seconds on/off; a no-seat badge takes priority.
- Customer revenue and the sales count are per bucket (**$18 each**), paid
  after the meal. The table displays the full bucket count. Customer routes
  account for tables and the counter; blocked routes wait and retry rather than
  using a fallback that crosses obstacles.
