CREATE DEFINER=`skip-grants user`@`skip-grants host` PROCEDURE `check_detail`(IN b_id VARCHAR(9), IN date DATETIME)
BEGIN
	
		DECLARE wrongmsg VARCHAR(90);
		DECLARE temp_A_transfer_id BIGINT; -- pay_log的transfer_id
		DECLARE temp_B_transfer_id BIGINT; -- transfer_log的transfer_id
		DECLARE temp_A_pay_amount DECIMAL(9,2);
		DECLARE temp_B_transfer_amount DECIMAL(9,2);
		DECLARE temp_A_pay_time DATETIME;
		DECLARE temp_B_transfer_time DATETIME;
		DECLARE temp_A_client_id BIGINT;
		DECLARE temp_B_client_id BIGINT;
		DECLARE v_finished INTEGER DEFAULT 0;
		-- 1.生成总表
		DECLARE error_log_cursor CURSOR FOR 
		SELECT A.transfer_id, B.transfer_id, A.pay_amount, B.transfer_amount, A.pay_time, B.transfer_time, A.client_id, B.client_id 
		FROM transfer_log B LEFT JOIN (SELECT * FROM pay_log WHERE pay_type = '缴费') A ON A.transfer_id = B.transfer_id 
		WHERE B.bank_id = b_id AND TO_DAYS(B.transfer_time) = TO_DAYS(date);
		
		DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_finished = 1;
		DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SELECT 'Exception';

		-- 2.生成错误记录
	  OPEN error_log_cursor;
    find_error: LOOP
		FETCH error_log_cursor INTO temp_A_transfer_id, temp_B_transfer_id, temp_A_pay_amount, temp_B_transfer_amount, temp_A_pay_time, temp_B_transfer_time, temp_A_client_id, temp_B_client_id;
		-- SELECT v_finished, temp_A_transfer_id, temp_B_transfer_id, temp_A_pay_amount, temp_B_transfer_amount, temp_A_pay_time, temp_B_transfer_time, temp_A_client_id, temp_B_client_id;
				IF v_finished = 1 THEN 
						LEAVE find_error;
				END IF;
				
				IF ISNULL(temp_A_transfer_id) = 1 THEN
						INSERT error_log(account_time, bank_id, transfer_id, client_id, bank_amount, enterprise_amount, error_type)
						VALUES (temp_B_transfer_time, b_id, temp_B_transfer_id, temp_B_client_id, temp_B_transfer_amount, 0, '企业方无流水信息');
				ELSEIF ISNULL(temp_B_transfer_id) = 1 THEN
						INSERT error_log(account_time, bank_id, transfer_id, client_id, bank_amount, enterprise_amount, account_info)
						VALUES (temp_A_pay_time, b_id, temp_A_transfer_id, temp_A_client_id, 0, temp_A_pay_amount, '银行方无流水信息');
 				ELSEIF temp_A_pay_amount <> temp_B_transfer_amount THEN 
 						INSERT error_log(account_time, bank_id, transfer_id, client_id, bank_amount, enterprise_amount, account_info)
 						VALUES (temp_A_pay_time, b_id, temp_A_transfer_id, temp_A_client_id, temp_B_transfer_amount, temp_A_pay_amount, '金额不等');
 				END IF;
		END LOOP find_error;
    CLOSE error_log_cursor;
END