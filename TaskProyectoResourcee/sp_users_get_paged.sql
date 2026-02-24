CREATE OR ALTER PROCEDURE dbo.sp_users_get_paged
    @PageNumber INT = 1,
    @PageSize   INT = 20,
    @Search     NVARCHAR(200) = NULL,
    @IsActive   BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Normalización básica
    IF (@PageNumber IS NULL OR @PageNumber < 1) SET @PageNumber = 1;
    IF (@PageSize   IS NULL OR @PageSize   < 1) SET @PageSize   = 20;
    IF (@PageSize > 200) SET @PageSize = 200;

    SET @Search = NULLIF(LTRIM(RTRIM(@Search)), N'');

    ;WITH Filtered AS
    (
        SELECT
            u.Id,
            u.Name,
            u.Email,
            u.IsActive,
            u.CreatedAtUtc,
            u.UpdatedAtUtc,
            TotalCount = COUNT_BIG(1) OVER()
        FROM dbo.Users u
        WHERE
            (@IsActive IS NULL OR u.IsActive = @IsActive)
            AND (
                @Search IS NULL
                OR u.Name  LIKE N'%' + @Search + N'%'
                OR u.Email LIKE N'%' + @Search + N'%'
            )
    )
    SELECT
        Id,
        Name,
        Email,
        IsActive,
        CreatedAtUtc,
        UpdatedAtUtc,
        TotalCount
    FROM Filtered
    ORDER BY CreatedAtUtc DESC, Id DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO