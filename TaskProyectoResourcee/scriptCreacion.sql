/* =========================================================
   SQL Server (T-SQL) - TaskManagerDb
   Estructura + Seed (Users / Tasks)
   ========================================================= */

SET NOCOUNT ON;

IF DB_ID('TaskManagerDb') IS NULL
BEGIN
    CREATE DATABASE TaskManagerDb;
END
GO

USE TaskManagerDb;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRAN;

    /* -----------------------------
       1) LIMPIEZA (si existía)
       ----------------------------- */
    IF OBJECT_ID('dbo.trg_Tasks_SetUpdatedAt', 'TR') IS NOT NULL
        DROP TRIGGER dbo.trg_Tasks_SetUpdatedAt;

    IF OBJECT_ID('dbo.trg_Users_SetUpdatedAt', 'TR') IS NOT NULL
        DROP TRIGGER dbo.trg_Users_SetUpdatedAt;

    IF OBJECT_ID('dbo.Tasks', 'U') IS NOT NULL
        DROP TABLE dbo.Tasks;

    IF OBJECT_ID('dbo.Users', 'U') IS NOT NULL
        DROP TABLE dbo.Users;

    /* -----------------------------
       2) TABLA: Users
       ----------------------------- */
    CREATE TABLE dbo.Users
    (
        UserId      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Users PRIMARY KEY,
        FullName    NVARCHAR(120)     NOT NULL,
        Email       NVARCHAR(180)     NOT NULL,
        [Role]      NVARCHAR(30)      NOT NULL CONSTRAINT DF_Users_Role DEFAULT (N'user'),
        IsActive    BIT               NOT NULL CONSTRAINT DF_Users_IsActive DEFAULT (1),
        CreatedAt   DATETIME2(0)      NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt   DATETIME2(0)      NOT NULL CONSTRAINT DF_Users_UpdatedAt DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT UQ_Users_Email UNIQUE (Email),
        CONSTRAINT CK_Users_Role CHECK ([Role] IN (N'admin', N'manager', N'user'))
    );

    /* -----------------------------
       3) TABLA: Tasks
       ----------------------------- */
    CREATE TABLE dbo.Tasks
    (
        TaskId        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Tasks PRIMARY KEY,
        UserId        INT               NOT NULL,
        Title         NVARCHAR(160)     NOT NULL,
        [Description] NVARCHAR(MAX)     NULL,
        [Status]      NVARCHAR(20)      NOT NULL CONSTRAINT DF_Tasks_Status DEFAULT (N'todo'),
        Priority      NVARCHAR(10)      NOT NULL CONSTRAINT DF_Tasks_Priority DEFAULT (N'medium'),
        DueDate       DATE              NULL,
        CreatedAt     DATETIME2(0)      NOT NULL CONSTRAINT DF_Tasks_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt     DATETIME2(0)      NOT NULL CONSTRAINT DF_Tasks_UpdatedAt DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT FK_Tasks_Users FOREIGN KEY (UserId)
            REFERENCES dbo.Users(UserId)
            ON DELETE CASCADE,

        CONSTRAINT CK_Tasks_Status CHECK ([Status] IN (N'todo', N'in_progress', N'blocked', N'done')),
        CONSTRAINT CK_Tasks_Priority CHECK (Priority IN (N'low', N'medium', N'high', N'urgent'))
    );

    /* -----------------------------
       4) ÍNDICES ÚTILES
       ----------------------------- */
    CREATE INDEX IX_Tasks_UserId  ON dbo.Tasks(UserId);
    CREATE INDEX IX_Tasks_Status  ON dbo.Tasks([Status]);
    CREATE INDEX IX_Tasks_DueDate ON dbo.Tasks(DueDate);

    /* -----------------------------
       5) TRIGGERS UpdatedAt
       (en dynamic SQL para evitar GO)
       ----------------------------- */
    EXEC(N'
    CREATE TRIGGER dbo.trg_Users_SetUpdatedAt
    ON dbo.Users
    AFTER UPDATE
    AS
    BEGIN
        SET NOCOUNT ON;

        UPDATE u
           SET UpdatedAt = SYSUTCDATETIME()
        FROM dbo.Users u
        INNER JOIN inserted i ON i.UserId = u.UserId;
    END;');

    EXEC(N'
    CREATE TRIGGER dbo.trg_Tasks_SetUpdatedAt
    ON dbo.Tasks
    AFTER UPDATE
    AS
    BEGIN
        SET NOCOUNT ON;

        UPDATE t
           SET UpdatedAt = SYSUTCDATETIME()
        FROM dbo.Tasks t
        INNER JOIN inserted i ON i.TaskId = t.TaskId;
    END;');

    /* -----------------------------
       6) SEED: USERS
       ----------------------------- */
    INSERT INTO dbo.Users (FullName, Email, [Role])
    VALUES
        (N'Sofía Ramírez',     N'sofia.ramirez@example.com',     N'admin'),
        (N'Mateo Fernández',   N'mateo.fernandez@example.com',   N'manager'),
        (N'Valentina Gómez',   N'valentina.gomez@example.com',   N'user'),
        (N'Sebastián Torres',  N'sebastian.torres@example.com',  N'user'),
        (N'Isabella Rojas',    N'isabella.rojas@example.com',    N'user'),
        (N'Daniela Martínez',  N'daniela.martinez@example.com',  N'user'),
        (N'Juan Pablo Silva',  N'juanpablo.silva@example.com',   N'user'),
        (N'Camila Herrera',    N'camila.herrera@example.com',    N'user');

    /* -----------------------------
       7) SEED: TASKS (asignación por Email)
       ----------------------------- */
    DECLARE @today DATE = CAST(GETDATE() AS DATE);

    INSERT INTO dbo.Tasks (UserId, Title, [Description], [Status], Priority, DueDate)
    VALUES
        ((SELECT UserId FROM dbo.Users WHERE Email = N'sofia.ramirez@example.com'),
         N'Configurar entorno del proyecto',
         N'Crear configuración base, variables y conexión a base de datos.',
         N'in_progress', N'high', DATEADD(day, 2, @today)),

        ((SELECT UserId FROM dbo.Users WHERE Email = N'sofia.ramirez@example.com'),
         N'Revisar permisos y roles',
         N'Definir permisos mínimos para admin/manager/user y documentar.',
         N'todo', N'medium', DATEADD(day, 5, @today)),

        ((SELECT UserId FROM dbo.Users WHERE Email = N'mateo.fernandez@example.com'),
         N'Plan de sprint semanal',
         N'Armar backlog, estimaciones y responsables.',
         N'todo', N'high', DATEADD(day, 1, @today)),

        ((SELECT UserId FROM dbo.Users WHERE Email = N'mateo.fernandez@example.com'),
         N'Reunión de seguimiento',
         N'Preparar agenda, riesgos y bloqueos.',
         N'todo', N'medium', DATEADD(day, 3, @today)),

        ((SELECT UserId FROM dbo.Users WHERE Email = N'valentina.gomez@example.com'),
         N'Diseñar pantalla de login',
         N'Mockup + validaciones y mensajes de error.',
         N'todo', N'medium', DATEADD(day, 7, @today)),

        ((SELECT UserId FROM dbo.Users WHERE Email = N'valentina.gomez@example.com'),
         N'Implementar formulario de registro',
         N'Campos y validaciones del lado cliente.',
         N'blocked', N'high', DATEADD(day, 10, @today)),

        ((SELECT UserId FROM dbo.Users WHERE Email = N'sebastian.torres@example.com'),
         N'API: endpoint crear tarea',
         N'POST /tasks con validaciones.',
         N'in_progress', N'high', DATEADD(day, 4, @today)),

        ((SELECT UserId FROM dbo.Users WHERE Email = N'sebastian.torres@example.com'),
         N'API: endpoint listar tareas',
         N'GET /tasks con filtros (status/priority) y paginación.',
         N'todo', N'medium', DATEADD(day, 6, @today)),

        ((SELECT UserId FROM dbo.Users WHERE Email = N'isabella.rojas@example.com'),
         N'Base de datos: migraciones',
         N'Crear estructura inicial y constraints.',
         N'done', N'medium', DATEADD(day, -1, @today)),

        ((SELECT UserId FROM dbo.Users WHERE Email = N'isabella.rojas@example.com'),
         N'Seeds para demo',
         N'Usuarios y tareas de ejemplo para pruebas.',
         N'done', N'low', NULL),

        ((SELECT UserId FROM dbo.Users WHERE Email = N'daniela.martinez@example.com'),
         N'QA: checklist de pruebas',
         N'Casos felices, bordes y errores comunes.',
         N'todo', N'medium', DATEADD(day, 9, @today)),

        ((SELECT UserId FROM dbo.Users WHERE Email = N'juanpablo.silva@example.com'),
         N'UI: tablero de tareas',
         N'Columnas: todo / in_progress / blocked / done.',
         N'in_progress', N'high', DATEADD(day, 12, @today)),

        ((SELECT UserId FROM dbo.Users WHERE Email = N'camila.herrera@example.com'),
         N'Documentación README',
         N'Instalación, variables, comandos y scripts.',
         N'todo', N'medium', DATEADD(day, 3, @today));

    COMMIT TRAN;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;

    DECLARE @ErrMsg  NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrLine INT            = ERROR_LINE();

    RAISERROR(N'Error en el script (línea %d): %s', 16, 1, @ErrLine, @ErrMsg);
END CATCH;

/* -----------------------------
   CONSULTAS ÚTILES (opcional)
   ----------------------------- */
-- Ver tareas con su usuario:
-- SELECT t.*, u.FullName, u.Email
-- FROM dbo.Tasks t
-- JOIN dbo.Users u ON u.UserId = t.UserId
-- ORDER BY t.DueDate ASC, t.Priority DESC;

-- Pendientes por usuario:
-- SELECT u.FullName, COUNT(*) AS Pending
-- FROM dbo.Tasks t
-- JOIN dbo.Users u ON u.UserId = t.UserId
-- WHERE t.[Status] <> N'done'
-- GROUP BY u.FullName
-- ORDER BY Pending DESC;