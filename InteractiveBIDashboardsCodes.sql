#### Interactive Plan

##### Database Maintenance
#### BR1. Maintain customer purchase history (for loyalty program)
SELECT c.customerid, c.email, COUNT(s.saleid) AS total_purchases,
       MAX(s.saledate) AS last_purchase, SUM(p.amount) AS total_spent
FROM customers c
JOIN sales s ON s.customerid = c.customerid
JOIN payments p ON p.saleid = s.saleid
WHERE p.paymenttype = 'Customer'
GROUP BY c.customerid, c.email;

#### BR2. Track all payment transactions incl. refunds, discounts
SELECT *
FROM payments
ORDER BY paymentdate DESC;


#### BR3. Track staffing: schedules, shifts, time-off
SELECT e.employeeid, e.firstname || ' ' || e.lastname AS name,
       COUNT(es.shiftid) AS shifts_worked,
       ROUND(SUM(EXTRACT(EPOCH FROM (es.shiftend - es.shiftstart)) / 3600)::numeric, 2) AS total_hours
FROM employees e
JOIN employeeshift es ON es.employeeid = e.employeeid
GROUP BY e.employeeid, name
ORDER BY total_hours DESC;


##### Report Level
#### BR4. Financial reports: revenue, costs, net income by store
SELECT s.storeid, s.storename,
       SUM(p.amount) FILTER (WHERE p.paymenttype = 'Customer') AS revenue,
       SUM(p.amount) FILTER (WHERE p.paymenttype = 'Vendor') AS cost,
       COALESCE(SUM(p.amount) FILTER (WHERE p.paymenttype = 'Customer'), 0) -
       COALESCE(SUM(p.amount) FILTER (WHERE p.paymenttype = 'Vendor'), 0) AS net_income
FROM payments p
JOIN sales sa ON p.saleid = sa.saleid
JOIN stores s ON sa.storeid = s.storeid
GROUP BY s.storeid, s.storename
ORDER BY net_income DESC;

#### BR5. Track employee performance
SELECT 
  e.employeeid, 
  e.firstname || ' ' || e.lastname AS name,
  COUNT(sa.saleid) AS total_sales,
  SUM(p.amount) FILTER (WHERE p.paymenttype = 'Customer') AS revenue
FROM employees e
JOIN sales sa ON sa.employeeid = e.employeeid
JOIN payments p ON p.saleid = sa.saleid
GROUP BY e.employeeid, name
HAVING SUM(p.amount) FILTER (WHERE p.paymenttype = 'Customer') IS NOT NULL
ORDER BY revenue DESC;


#### BR6. Real-time stock & restocking
SELECT i.storeid, s.storename, p.productname, i.quantity, i.lowstockthreshold
FROM inventory i
JOIN stores s ON s.storeid = i.storeid
JOIN products p ON p.productid = i.productid
WHERE i.quantity <= i.lowstockthreshold;


#### BR7. Inactive product report
SELECT p.productid, p.productname, p.isactive, 
       MAX(sd.saleid) AS last_sold_saleid,
       MAX(sa.saledate) AS last_sold_date
FROM products p
LEFT JOIN saledetails sd ON p.productid = sd.productid
LEFT JOIN sales sa ON sd.saleid = sa.saleid
WHERE p.isactive = FALSE
GROUP BY p.productid, p.productname, p.isactive
ORDER BY last_sold_date DESC NULLS LAST;

#### BR7a. Active product report
SELECT p.productid, p.productname, p.isactive, 
       MAX(sd.saleid) AS last_sold_saleid,
       MAX(sa.saledate) AS last_sold_date
FROM products p
LEFT JOIN saledetails sd ON p.productid = sd.productid
LEFT JOIN sales sa ON sd.saleid = sa.saleid
WHERE p.isactive = TRUE
GROUP BY p.productid, p.productname, p.isactive
ORDER BY last_sold_date DESC NULLS LAST;

#### BR8. Vendor delivery efficiency
SELECT d.deliveryid, v.vendorname, d.deliverydate, d.status,
       COUNT(dd.deliverydetailid) AS items
FROM deliveries d
JOIN vendors v ON v.vendorid = d.vendorid
JOIN deliverydetails dd ON dd.deliveryid = d.deliveryid
WHERE d.status IN ('Partial', 'Pending')
  AND dd.expirydate < NOW()
GROUP BY d.deliveryid, v.vendorname, d.deliverydate, d.status;

#### BR9. Payroll and bonus metrics
SELECT e.employeeid, e.firstname || ' ' || e.lastname AS name,
       ROUND(SUM(EXTRACT(EPOCH FROM (es.shiftend - es.shiftstart)) / 3600)::numeric, 2) AS total_hours,
       COUNT(sa.saleid) AS sales_handled,
       COALESCE(SUM(p.amount) FILTER (WHERE p.paymenttype = 'Customer'), 0) AS sales_value
FROM employees e
JOIN employeeshift es ON es.employeeid = e.employeeid
LEFT JOIN sales sa ON sa.employeeid = e.employeeid
LEFT JOIN payments p ON p.saleid = sa.saleid
GROUP BY e.employeeid, name;

### Updated with only employee with sales value
SELECT e.employeeid, e.firstname || ' ' || e.lastname AS name,
       ROUND(SUM(EXTRACT(EPOCH FROM (es.shiftend - es.shiftstart)) / 3600)::numeric, 2) AS total_hours,
       COUNT(sa.saleid) AS sales_handled,
       COALESCE(SUM(p.amount) FILTER (WHERE p.paymenttype = 'Customer'), 0) AS sales_value
FROM employees e
JOIN employeeshift es ON es.employeeid = e.employeeid
LEFT JOIN sales sa ON sa.employeeid = e.employeeid
LEFT JOIN payments p ON p.saleid = sa.saleid
GROUP BY e.employeeid, name
HAVING COALESCE(SUM(p.amount) FILTER (WHERE p.paymenttype = 'Customer'), 0) > 0
ORDER BY sales_value DESC
LIMIT 200;

##### Analyst Level
#### BR10. Profitability by store
(Same as #BR4)

#### BR11. High-traffic shelves/aisles
SELECT p.aisle, p.shelf, SUM(sd.quantity) AS total_units
FROM saledetails sd
JOIN products p ON sd.productid = p.productid
GROUP BY p.aisle, p.shelf
ORDER BY total_units DESC;

#### BR12. Promotion impact (before / during / after)
SELECT promo.promotionid, promo.promotionname,
       SUM(CASE WHEN s.saledate < promo.startdate THEN sd.quantity ELSE 0 END) AS before,
       SUM(CASE WHEN s.saledate BETWEEN promo.startdate AND promo.enddate THEN sd.quantity ELSE 0 END) AS during,
       SUM(CASE WHEN s.saledate > promo.enddate THEN sd.quantity ELSE 0 END) AS after
FROM promotions promo
JOIN sales s ON s.promotionid = promo.promotionid
JOIN saledetails sd ON sd.saleid = s.saleid
GROUP BY promo.promotionid, promo.promotionname;

### Updated for better visualization
WITH promo_stats AS (
  SELECT promo.promotionid, promo.promotionname,
         SUM(CASE WHEN s.saledate < promo.startdate THEN sd.quantity ELSE 0 END) AS before,
         SUM(CASE WHEN s.saledate BETWEEN promo.startdate AND promo.enddate THEN sd.quantity ELSE 0 END) AS during,
         SUM(CASE WHEN s.saledate > promo.enddate THEN sd.quantity ELSE 0 END) AS after
  FROM promotions promo
  JOIN sales s ON s.promotionid = promo.promotionid
  JOIN saledetails sd ON sd.saleid = s.saleid
  GROUP BY promo.promotionid, promo.promotionname
)
SELECT *
FROM promo_stats
ORDER BY during DESC
LIMIT 10;


#### BR13. Seasonal sales trends
SELECT st.storeid, st.storename, DATE_TRUNC('month', sa.saledate) AS month, 
       SUM(p.amount) FILTER (WHERE p.paymenttype = 'Customer') AS revenue
FROM sales sa
JOIN payments p ON p.saleid = sa.saleid
JOIN stores st ON st.storeid = sa.storeid
GROUP BY st.storeid, st.storename, month
ORDER BY month;

#### BR14. Reactivate inactive products
(Same as #BR7)


##### Vague, Not sure?
#### BR15. Automated vendor order trigger (tentative)
SELECT i.storeid, s.storename, p.productname, i.quantity,
       i.lowstockthreshold, i.reorderquantity
FROM inventory i
JOIN stores s ON s.storeid = i.storeid
JOIN products p ON p.productid = i.productid
WHERE i.quantity < i.lowstockthreshold;


### OR
SELECT 
  SUM(i.reorderquantity - i.quantity) AS total_units_to_restock
FROM inventory i
WHERE i.quantity < i.lowstockthreshold;


#### BR16. Layout optimization by sales flow
### (Same as #BR11)


##### NEW
#### BQ17. Targeted discount insights (promotion + customer behavior)
SELECT c.customerid, c.email,
       COUNT(DISTINCT s.promotionid) AS promotions_used,
       SUM(sd.quantity) AS quantity
FROM customers c
JOIN sales s ON s.customerid = c.customerid
JOIN saledetails sd ON sd.saleid = s.saleid
WHERE s.promotionid IS NOT NULL
GROUP BY c.customerid, c.email;


