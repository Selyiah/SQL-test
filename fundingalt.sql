/* Create the SQL Code for the following Aggregate View that links all the tables and
provides a summary of invoice payments and status. The view should include the following fields:
a. invoice_id
b. transaction_id
c. facility_id
d. facility_name
e. invoice_number
f. invoice_date
g. invoice_due_date
h. amount
i. total_payment: The total sum of all payments made towards the invoice.
j. remaining_balance: The remaining balance of the invoice after payments and
discount fee (with VAT) are applied.
k. invoice_status_id: The status ID of the invoice.
l. facility_fee: The facility fee proportionally distributed among the invoices in the
first transaction of the facility.
i. This fee is only applied to the first transaction of an invoice.
ii. The facility fee is evenly distributed among the invoices in the first transaction. For example, if the facility fee is $100 and there are two invoices in the first transaction with amounts $2000 and $8000, then 20% ($20) of the facility fee goes to the $2000 invoice and 80% ($80) goes to the $8000 invoice.
m. discount_fee_percentage:Thediscountfeepercentageofthefacilitylinkedto the invoice.
n. discount_fee_amount_with_vat: The discount fee amount (including VAT). This is calculated by invoice.amount * discount_fee_percentage * 1+the current VAT rate */

USE fundingalt;

CREATE VIEW receipt AS
SELECT
    i.invoice_id,
    t.transaction_id,
    f.facility_id,
    f.facility_name,
    i.invoice_number,
    i.invoice_date,
    i.invoice_due_date,
    i.amount,
    COALESCE(SUM(p.amount_paid), 0) AS total_payment,
    i.amount - COALESCE(SUM(p.amount_paid), 0) - (i.amount * f.discount_fee_percentage / 100 * (1 + v.vat_rate / 100)) AS remaining_balance,
    i.invoice_status_id,
    CASE
        WHEN t.transaction_id = ft.first_transaction_id THEN
            f.facility_fee * i.amount / (
                SELECT SUM(i2.amount)
                FROM invoices i2
                JOIN transactions t2 ON i2.transaction_id = t2.transaction_id
                WHERE t2.facility_id = f.facility_id
                  AND t2.transaction_id = ft.first_transaction_id
            )
        ELSE 0
    END AS facility_fee,
    f.discount_fee_percentage,
    i.amount * f.discount_fee_percentage / 100 * (1 + v.vat_rate / 100) AS discount_fee_amount_with_vat
FROM
    invoices i
JOIN
    transactions t ON i.transaction_id = t.transaction_id
JOIN
    facilities f ON t.facility_id = f.facility_id
LEFT JOIN
    payments p ON i.invoice_id = p.invoice_id
JOIN
    (SELECT vat_rate FROM vat_settings WHERE current = TRUE) v
JOIN
    (SELECT facility_id, MIN(transaction_id) AS first_transaction_id
     FROM transactions
     GROUP BY facility_id) ft ON t.facility_id = ft.facility_id
GROUP BY
    i.invoice_id,
    t.transaction_id,
    f.facility_id,
    f.facility_name,
    i.invoice_number,
    i.invoice_date,
    i.invoice_due_date,
    i.amount,
    i.invoice_status_id,
    f.facility_fee,
    f.discount_fee_percentage,
    v.vat_rate,
    ft.first_transaction_id;

SELECT * FROM fundingalt.receipt;
