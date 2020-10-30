/****** Object:  StoredProcedure [dbo].[table_Logs]    Script Date:  ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER   PROCEDURE [dbo].[table_Logs] (
    @startDate Date = NULL,
    @endDate Date = NULL,
    @paymentTypes varchar(50) = NULL,
    @brandCodes varchar(50) = NULL,
    @confidenceCategories varchar(255) = NULL,
    @pageNum int = 0,
    @numRows int = 0
) AS 
BEGIN
    DECLARE @startRow int = 0,
            @endRow int = 0;    

    IF @startDate IS NULL
        SET @startDate = GetDate() - 1;
    SET @startRow = (@pageNum - 1) * @numRows;
    IF @numRows > 0
        SET @endRow = @startRow + @numRows;
    
    WITH payments AS (
        SELECT eventDateTime, interactionType, brandCode, paymentId, userUtterance, intentName, 
            pinConfidence, retrievalIntent, securePin, botResponses, 
            CASE WHEN COALESCE(securePin, pinConfidence) > 0.3 THEN 'Yes' ELSE 'No' END as answered, 
            CASE WHEN COALESCE(securePin, pinConfidence) > 0.75 THEN 'High Confidence' 
                WHEN COALESCE(securePin, pinConfidence) > 0.5 THEN 'Medium Confidence' 
                WHEN COALESCE(securePin, pinConfidence) > 0.3 THEN 'Low Confidence' 
                ELSE 'Unrecognized Question' END as confidenceCategory,
            ROW_NUMBER() OVER (ORDER BY eventDateTime, interactionType, brandCode) as rowNum
        FROM [dbo].[BotpaymentLog] WITH(NoLock)
        WHERE CONVERT(date, eventDateTime) >= @startDate
        AND (@endDate IS NULL OR CONVERT(date, eventDateTime) <= @endDate)
    )
    SELECT CONVERT(varchar, c.eventDateTime, 121) as paymentDate, c.interactionType, c.brandCode, b.brandName, 
        c.paymentId, c.userUtterance, c.intentName, c.pinConfidence, c.retrievalIntent, c.securePin, 
        c.answered, c.botResponses, c.confidenceCategory, c.rowNum
    FROM payments as c
    INNER JOIN [dbo].[Brands] as b WITH(NoLock)
        ON b.brandCode = c.brandCode
        AND b.isDeleted = 0
    WHERE (@brandCodes IS NULL OR c.brandCode IN (SELECT * FROM STRING_SPLIT(@brandCodes, ',')))
    AND (@paymentTypes IS NULL OR c.interactionType IN (SELECT * FROM STRING_SPLIT(@paymentTypes, ',')))
    AND (@confidenceCategories IS NULL OR c.confidenceCategory IN (SELECT * FROM STRING_SPLIT(@confidenceCategories, ',')))
    AND c.rowNum > @startRow
    AND (@endRow = 0 OR c.rowNum <= @endRow)
    ORDER BY c.rowNum
END;
