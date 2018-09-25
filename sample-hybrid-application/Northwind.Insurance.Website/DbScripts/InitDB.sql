IF OBJECT_ID(N'__EFMigrationsHistory') IS NULL
BEGIN
    CREATE TABLE [__EFMigrationsHistory] (
        [MigrationId] nvarchar(150) NOT NULL,
        [ProductVersion] nvarchar(32) NOT NULL,
        CONSTRAINT [PK___EFMigrationsHistory] PRIMARY KEY ([MigrationId])
    );
END;

GO

CREATE TABLE [InsurancePlans] (
    [InsurancePlanId] int NOT NULL IDENTITY,
    [ERVisitAfterDeductible] float NOT NULL,
    [FamilyDeductible] float NOT NULL,
    [FamilyOutOfPocketMax] float NOT NULL,
    [FreePrimaryCareVisits] int NOT NULL,
    [IndividualDeductible] float NOT NULL,
    [IndividualOutOfPocketMax] float NOT NULL,
    [Level] int NOT NULL,
    [PlanName] nvarchar(max),
    [Premium] float NOT NULL,
    [PrimaryCareVisitCostAfterDeductible] float NOT NULL,
    CONSTRAINT [PK_InsurancePlans] PRIMARY KEY ([InsurancePlanId])
);

GO

CREATE TABLE [Subscribers] (
    [SubscriberID] int NOT NULL IDENTITY,
    [AddressLine1] nvarchar(max),
    [AddressLine2] nvarchar(max),
    [AlimonyChildSupport] float NOT NULL,
    [City] nvarchar(max),
    [County] nvarchar(max),
    [EmailAddress] nvarchar(max),
    [EmploymentIncome] float NOT NULL,
    [FirstName] nvarchar(max),
    [InvestmentIncome] float NOT NULL,
    [IsMilitary] bit NOT NULL,
    [IsOnDisability] bit NOT NULL,
    [IsOnMedicare] bit NOT NULL,
    [IsStudent] bit NOT NULL,
    [IsUSCitizen] bit NOT NULL,
    [LastName] nvarchar(max),
    [MiddleName] nvarchar(max),
    [PhoneNumber] nvarchar(max),
    [SocialSecurityNumber] nvarchar(max),
    [State] nvarchar(max),
    [ZipCode] nvarchar(max),
    CONSTRAINT [PK_Subscribers] PRIMARY KEY ([SubscriberID])
);

GO

CREATE TABLE [Enrollments] (
    [EnrollmentID] int NOT NULL IDENTITY,
    [InsurancePlanID] int NOT NULL,
    [PlanYear] int NOT NULL,
    [SubscriberID] int NOT NULL,
    CONSTRAINT [PK_Enrollments] PRIMARY KEY ([EnrollmentID]),
    CONSTRAINT [FK_Enrollments_InsurancePlans_InsurancePlanID] FOREIGN KEY ([InsurancePlanID]) REFERENCES [InsurancePlans] ([InsurancePlanId]) ON DELETE CASCADE,
    CONSTRAINT [FK_Enrollments_Subscribers_SubscriberID] FOREIGN KEY ([SubscriberID]) REFERENCES [Subscribers] ([SubscriberID]) ON DELETE CASCADE
);

GO

CREATE TABLE [HouseholdMembers] (
    [HouseholdMemberID] int NOT NULL IDENTITY,
    [DateOfBirth] nvarchar(max),
    [Gender] int NOT NULL,
    [Relationship] int NOT NULL,
    [SubscriberID] int,
    [TobaccoUse] int NOT NULL,
    CONSTRAINT [PK_HouseholdMembers] PRIMARY KEY ([HouseholdMemberID]),
    CONSTRAINT [FK_HouseholdMembers_Subscribers_SubscriberID] FOREIGN KEY ([SubscriberID]) REFERENCES [Subscribers] ([SubscriberID]) ON DELETE NO ACTION
);

GO

CREATE INDEX [IX_Enrollments_InsurancePlanID] ON [Enrollments] ([InsurancePlanID]);

GO

CREATE INDEX [IX_Enrollments_SubscriberID] ON [Enrollments] ([SubscriberID]);

GO

CREATE INDEX [IX_HouseholdMembers_SubscriberID] ON [HouseholdMembers] ([SubscriberID]);

GO

INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
VALUES (N'20170705101701_InitialCreate', N'1.1.2');

GO

ALTER TABLE [InsurancePlans] ADD [IsSpecial] bit NOT NULL DEFAULT 0;

GO

INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
VALUES (N'20170706005142_IsSpecial', N'1.1.2');

GO

ALTER TABLE [Enrollments] ADD [ConfirmationCode] nvarchar(max);

GO

INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
VALUES (N'20170706030119_ConfirmationCode', N'1.1.2');

GO

