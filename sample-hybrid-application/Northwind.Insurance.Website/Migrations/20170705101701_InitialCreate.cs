using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore.Metadata;

namespace Northwind.Insurance.Website.Migrations
{
    public partial class InitialCreate : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "InsurancePlans",
                columns: table => new
                {
                    InsurancePlanId = table.Column<int>(nullable: false)
                        .Annotation("SqlServer:ValueGenerationStrategy", SqlServerValueGenerationStrategy.IdentityColumn),
                    ERVisitAfterDeductible = table.Column<double>(nullable: false),
                    FamilyDeductible = table.Column<double>(nullable: false),
                    FamilyOutOfPocketMax = table.Column<double>(nullable: false),
                    FreePrimaryCareVisits = table.Column<int>(nullable: false),
                    IndividualDeductible = table.Column<double>(nullable: false),
                    IndividualOutOfPocketMax = table.Column<double>(nullable: false),
                    Level = table.Column<int>(nullable: false),
                    PlanName = table.Column<string>(nullable: true),
                    Premium = table.Column<double>(nullable: false),
                    PrimaryCareVisitCostAfterDeductible = table.Column<double>(nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_InsurancePlans", x => x.InsurancePlanId);
                });

            migrationBuilder.CreateTable(
                name: "Subscribers",
                columns: table => new
                {
                    SubscriberID = table.Column<int>(nullable: false)
                        .Annotation("SqlServer:ValueGenerationStrategy", SqlServerValueGenerationStrategy.IdentityColumn),
                    AddressLine1 = table.Column<string>(nullable: true),
                    AddressLine2 = table.Column<string>(nullable: true),
                    AlimonyChildSupport = table.Column<double>(nullable: false),
                    City = table.Column<string>(nullable: true),
                    County = table.Column<string>(nullable: true),
                    EmailAddress = table.Column<string>(nullable: true),
                    EmploymentIncome = table.Column<double>(nullable: false),
                    FirstName = table.Column<string>(nullable: true),
                    InvestmentIncome = table.Column<double>(nullable: false),
                    IsMilitary = table.Column<bool>(nullable: false),
                    IsOnDisability = table.Column<bool>(nullable: false),
                    IsOnMedicare = table.Column<bool>(nullable: false),
                    IsStudent = table.Column<bool>(nullable: false),
                    IsUSCitizen = table.Column<bool>(nullable: false),
                    LastName = table.Column<string>(nullable: true),
                    MiddleName = table.Column<string>(nullable: true),
                    PhoneNumber = table.Column<string>(nullable: true),
                    SocialSecurityNumber = table.Column<string>(nullable: true),
                    State = table.Column<string>(nullable: true),
                    ZipCode = table.Column<string>(nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Subscribers", x => x.SubscriberID);
                });

            migrationBuilder.CreateTable(
                name: "Enrollments",
                columns: table => new
                {
                    EnrollmentID = table.Column<int>(nullable: false)
                        .Annotation("SqlServer:ValueGenerationStrategy", SqlServerValueGenerationStrategy.IdentityColumn),
                    InsurancePlanID = table.Column<int>(nullable: false),
                    PlanYear = table.Column<int>(nullable: false),
                    SubscriberID = table.Column<int>(nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Enrollments", x => x.EnrollmentID);
                    table.ForeignKey(
                        name: "FK_Enrollments_InsurancePlans_InsurancePlanID",
                        column: x => x.InsurancePlanID,
                        principalTable: "InsurancePlans",
                        principalColumn: "InsurancePlanId",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_Enrollments_Subscribers_SubscriberID",
                        column: x => x.SubscriberID,
                        principalTable: "Subscribers",
                        principalColumn: "SubscriberID",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "HouseholdMembers",
                columns: table => new
                {
                    HouseholdMemberID = table.Column<int>(nullable: false)
                        .Annotation("SqlServer:ValueGenerationStrategy", SqlServerValueGenerationStrategy.IdentityColumn),
                    DateOfBirth = table.Column<string>(nullable: true),
                    Gender = table.Column<int>(nullable: false),
                    Relationship = table.Column<int>(nullable: false),
                    SubscriberID = table.Column<int>(nullable: true),
                    TobaccoUse = table.Column<int>(nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_HouseholdMembers", x => x.HouseholdMemberID);
                    table.ForeignKey(
                        name: "FK_HouseholdMembers_Subscribers_SubscriberID",
                        column: x => x.SubscriberID,
                        principalTable: "Subscribers",
                        principalColumn: "SubscriberID",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Enrollments_InsurancePlanID",
                table: "Enrollments",
                column: "InsurancePlanID");

            migrationBuilder.CreateIndex(
                name: "IX_Enrollments_SubscriberID",
                table: "Enrollments",
                column: "SubscriberID");

            migrationBuilder.CreateIndex(
                name: "IX_HouseholdMembers_SubscriberID",
                table: "HouseholdMembers",
                column: "SubscriberID");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Enrollments");

            migrationBuilder.DropTable(
                name: "HouseholdMembers");

            migrationBuilder.DropTable(
                name: "InsurancePlans");

            migrationBuilder.DropTable(
                name: "Subscribers");
        }
    }
}
