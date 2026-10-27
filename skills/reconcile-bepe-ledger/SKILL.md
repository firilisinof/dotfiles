---
name: "reconcile-bepe-ledger"
description: "Reconcile bank activity into the \"controle financeiro BEPE\" sheet. Use when the user sends bank screenshots or transactions to log, or says a recurring cost changed."
disable-model-invocation: true
---

# Reconcile the BEPE ledger

Bank activity goes into the sheet until the ledger **ties**: the current month's *Somente confirmados* Saldo equals the user's real balances to the cent, in both currencies. A ledger that looks right but is off by 0,37 does not tie.

## Steps

1. **Extract.** List every transaction in every source the user gave (screenshots, pasted text, files): date, counterparty, amount, direction, currency, account. Resolve "Today / Ontem / Anteontem" against today's date. Done when every visible row of every source is on the list, including rows half-hidden under an app header.

2. **Read the ledger.** Open the tab of every month the list touches, plus the current month. Done when you know, per tab, every `Estimado` row and the newest `Confirmado` date.

3. **Classify.** Give each transaction exactly one class from *Classes*. Done when none is unclassified; whatever you cannot classify becomes a question in step 5.

4. **Tie.** Get the real balances from the user (total EUR, total BRL); ask if they were not given. Compute the confirmed Saldo per currency as it will stand after your changes. Done when each currency's gap is zero or explained to the cent by a named cause (see *Gaps*).

5. **Propose.** Show, per tab: new rows, estimates becoming confirmed (old value -> new value), what you left out and why, the gap, and your questions. Done when the user has approved. Nothing is written before that.

6. **Write.** Apply the changes following *Writing*. Done when a fresh read shows all three: *Somente confirmados* Saldo equals the real balances exactly, every new row has its BRL or EUR column filled, every new date displays as dd/mm/yyyy.

7. **Report.** State the confirmed and the projected Saldo. Name every recurring charge that came in different from its estimate and ask whether to carry the new value into the future tabs (see *Future estimates*).

## Classes

- **Internal** - money moving between the user's own accounts (N26, Wise, Nubank). Signs: the counterparty is "Lucas de Sousa Rosa"; Wise shows "Para EUR - Adicionado"; the same amount leaves one account and lands in another. Not entered. An uncertain internal guess is settled by step 4: if the ledger ties with it left out, it was internal.
- **Conversion** - Wise "Para BRL - Movimentado" (or the reverse). Entered as a pair on the same date: Despesa `Conversão de saldo (EUR -> BRL)` in the source currency, Receita `Conversão de saldo recebida` in the destination currency. The onward transfer of the converted money is Internal.
- **Realizes an estimate** - matches an `Estimado` row of that month. Edit that row in place: real date, real value, Situação `Confirmado`. Never add a second row for it.
- **Partial** - an Izly top-up. Add a confirmed row `Izly` and subtract the same amount inside the formula of the `Refeições CROUS` estimate of that month.
- **Already entered** - a row with the same date, value and currency exists. Skip.
- **New** - everything else. One confirmed row.

## Naming

Descrição is the store name only, as the statement shows it, unless the table says otherwise.

| Statement shows | Descrição |
|---|---|
| FUNDACAO DE AMPARO... | `Bolsa BEPE-FAPESP (n/12)` |
| Gabriel FERREIRA FERNA... 470,00 | `Aluguel` |
| M TAG (monthly pass) | `Transporte público` |
| Free Mobile | `Fatura: Free Mobile` |
| N26 4,90 | `Anuidade: N26` |
| Nubank "Pagamento da fatura" | `Fatura: NuBank` |
| Pix to Santander | `Fatura: Santander` |
| Nubank "Parcela paga - Empréstimo" | `Empréstimo: Meu e da Mãe (n/24)` / `Empréstimo: Mãe (n/24)` - match by value |
| Pix from Juliana Caroline de Sousa | `Dinheiro da mãe` |
| Cash Services (ATM) | `Saque (Cash Services)` - Despesa; cash is not tracked |
| PayPal | `<merchant> (PayPal)` - ask the user for the merchant unless it matches an installment estimate |

## Gaps

- N26's sticky header shows the account balance at the scroll position. Balances in two screenshots must differ by exactly the transactions between them; a mismatch means a row you have not seen.
- A gap of a unit or more means a missing or misclassified transaction. Find it, or ask for the missing statement, before proposing.
- A residue of cents with nothing missing: propose a row `Correção do saldo EUR` or `Correção do saldo BRL`, dated today, Receita when the ledger is short and Despesa when it is over.

## Sheet

- Spreadsheet ID `1RVjAtPWaIvJXx7wxMNntrzlHO567P8TCTk_duhde63k`. Open it by ID; the Drive connector cannot search by name.
- Tabs: `Visão Geral`, then one per month, `Setembro 2026` to `Agosto 2027`.
- Row 10, headers: Data | Descrição | Tipo | Situação | Valor | Moeda | BRL | EUR.
- Rows 11-12: opening balances carried from the previous tab by formula. Never edit them; a change in an earlier month flows forward by itself.
- Row 13 down: entries, newest first.
- Tipo `Receita` or `Despesa`. Situação `Confirmado` or `Estimado`. Valor always positive. Moeda `BRL` or `EUR`.
- Rows 5-7: Receitas, Despesas, Saldo. Columns B:C count every row (projected); D:E are *Somente confirmados*.

## Writing

- A transaction goes in the tab of its own date, even when that month is already past.
- Insert rows inside the entry block, at the position the date belongs, inheriting format from an ordinary entry row and not from rows 11-12. Re-read the block after inserting: row numbers have shifted.
- Columns G and H are formulas that inserted rows do not inherit. For row r write `=IF(AND($Er<>"",$Fr="BRL"),$Er,"")` in G and `=IF(AND($Er<>"",$Fr="EUR"),$Er,"")` in H.
- The locale is en_US: a typed `05/10/2026` becomes May 10. Write dates as serial numbers (01/10/2026 = 46296, plus 1 per day); if the cell then displays a number, apply the dd/mm/yyyy format.

## Future estimates

Recurring charges sit as `Estimado` rows in every future tab. When the user confirms a new recurring value, change the Valor of that row in every future tab, finding it by Descrição because its row number differs per tab. Before writing, ask whether the charge that triggered the change includes a one-off or pro-rata amount.