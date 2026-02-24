CREATE OR ALTER PROCEDURE dbo.sp_tasks_get_paged
    @PageNumber     INT = 1,
    @PageSize       INT = 20,
    @AssignedUserId UNIQUEIDENTIFIER = NULL,
    @Status         NVARCHAR(50) = NULL,            -- "Pending" | "InProgress" | "Done"
    @PriorityId     UNIQUEIDENTIFIER = NULL,        -- MasterDataDetail.Id (opcional)
    @Tag            NVARCHAR(80) = NULL,            -- busca en AdditionalInfo JSON (opcional)
    @Search         NVARCHAR(200) = NULL            -- busca en Title/Description/UserName (opcional)
AS
BEGIN
    SET NOCOUNT ON;

    -- Normalización
    IF (@PageNumber IS NULL OR @PageNumber < 1) SET @PageNumber = 1;
    IF (@PageSize   IS NULL OR @PageSize   < 1) SET @PageSize   = 20;
    IF (@PageSize > 200) SET @PageSize = 200;

    SET @Status = NULLIF(LTRIM(RTRIM(@Status)), N'');
    SET @Tag    = NULLIF(LTRIM(RTRIM(@Tag)), N'');
    SET @Search = NULLIF(LTRIM(RTRIM(@Search)), N'');

    ;WITH Filtered AS
    (
        SELECT
            t.Id,
            t.Title,
            t.Description,
            t.AssignedUserId,
            AssignedUserName = u.Name,
            StatusId         = t.StatusId,
            Status           = s.Name,
            t.PriorityId,
            Priority         = p.Name,
            t.AdditionalInfo,
            t.CreatedAtUtc,
            t.UpdatedAtUtc,
            TotalCount       = COUNT_BIG(1) OVER()
        FROM dbo.Tasks t
        INNER JOIN dbo.Users u
            ON u.Id = t.AssignedUserId
        INNER JOIN dbo.MasterDataDetail s
            ON s.Id = t.StatusId
        LEFT JOIN dbo.MasterDataDetail p
            ON p.Id = t.PriorityId
        WHERE
            t.IsActive = 1
            AND (@AssignedUserId IS NULL OR t.AssignedUserId = @AssignedUserId)
            AND (@PriorityId IS NULL OR t.PriorityId = @PriorityId)
            AND (@Status IS NULL OR s.Name = @Status)
            AND (
                @Search IS NULL
                OR t.Title       LIKE N'%' + @Search + N'%'
                OR t.Description LIKE N'%' + @Search + N'%'
                OR u.Name        LIKE N'%' + @Search + N'%'
            )
            AND (
                @Tag IS NULL
                OR (
                    t.AdditionalInfo IS NOT NULL
                    AND ISJSON(t.AdditionalInfo) = 1
                    AND (
                        JSON_VALUE(t.AdditionalInfo, '$.tag') = @Tag
                        OR EXISTS (
                            SELECT 1
                            FROM OPENJSON(t.AdditionalInfo, '$.tags') j
                            WHERE j.[value] = @Tag
                        )
                    )
                )
            )
    )
    SELECT
        Id,
        Title,
        Description,
        AssignedUserId,
        AssignedUserName,
        StatusId,
        Status,
        PriorityId,
        Priority,
        CreatedAtUtc,
        UpdatedAtUtc,
        TotalCount
    FROM Filtered
    ORDER BY CreatedAtUtc DESC, Id DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO