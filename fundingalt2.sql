/* 3. Answer the following questions, providing SQL code to determine: a. What is the aggregate invoice value within each facility? */

USE fundingalt;

SELECT
    f.facility_id,
    f.facility_name,
    SUM(i.amount) AS aggregate_invoice_value
FROM
    invoices i
JOIN
    transactions t ON i.transaction_id = t.transaction_id
JOIN
    facilities f ON t.facility_id = f.facility_id
GROUP BY
    f.facility_id,
    f.facility_name;

/* b. What is the weighted average time that an invoice takes to get paid? */ 

USE fundingalt;

SELECT 
    SUM(DATEDIFF(p.payment_date, i.invoice_date) * p.amount_paid) / SUM(p.amount_paid) AS weighted_avg_payment_time
FROM
    invoices i
JOIN
    payments p ON i.invoice_id = p.invoice_id;

/* VAT rates change periodically, create a VAT table named tbIVAT, ranging from the year of 1900 to 2099 with various VAT rates applicables at each point in time. 
Modify your answer to question (2) in Deliverables by taking account of the above variability, ensuring that the invoice_date is used to determine which VAT rate to use for the discount fee.*/ 

/* first i created the table */

USE fundingalt;

CREATE TABLE `tbIVAT` (
    `vat_id` INT NOT NULL AUTO_INCREMENT,
    `vat_rate` DECIMAL(5,2) NOT NULL,
    `start_date` DATE NOT NULL,
    `end_date` DATE NOT NULL,
    PRIMARY KEY (`vat_id`)
);

INSERT INTO `tbIVAT` (vat_rate, start_date, end_date) VALUES
(10.00, '1900-01-01', '1949-12-31'),
(12.50, '1950-01-01', '1999-12-31'),
(15.00, '2000-01-01', '2024-01-01'),
(20.00, '2024-01-02', '2099-12-31');

SELECT * FROM `tbIVAT`;

/* then modify my code to reflect the changes in VAT */ 

USE fundingalt;

CREATE VIEW receipt_updated AS
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
    tbIVAT v ON i.invoice_date BETWEEN v.start_date AND v.end_date
JOIN
    facilities f ON t.facility_id = f.facility_id
LEFT JOIN
    payments p ON i.invoice_id = p.invoice_id
JOIN
    (SELECT facility_id, MIN(transaction_id) AS first_transaction_id FROM transactions GROUP BY facility_id) ft ON t.facility_id = ft.facility_id
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

SELECT * FROM receipt_updated;


