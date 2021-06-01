using System;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;
using Northwind.Insurance.Website.Models;

namespace Northwind.Insurance.Website.Migrations
{
    [DbContext(typeof(InsuranceContext))]
    partial class InsuranceContextModelSnapshot : ModelSnapshot
    {
        protected override void BuildModel(ModelBuilder modelBuilder)
        {
            modelBuilder
                .HasAnnotation("ProductVersion", "1.1.2")
                .HasAnnotation("SqlServer:ValueGenerationStrategy", SqlServerValueGenerationStrategy.IdentityColumn);

            modelBuilder.Entity("Northwind.Insurance.Website.Models.Enrollment", b =>
                {
                    b.Property<int>("EnrollmentID")
                        .ValueGeneratedOnAdd();

                    b.Property<string>("ConfirmationCode");

                    b.Property<int>("InsurancePlanID");

                    b.Property<int>("PlanYear");

                    b.Property<int>("SubscriberID");

                    b.Property<DateTime?>("TimeStamp");

                    b.HasKey("EnrollmentID");

                    b.HasIndex("InsurancePlanID");

                    b.HasIndex("SubscriberID");

                    b.ToTable("Enrollments");
                });

            modelBuilder.Entity("Northwind.Insurance.Website.Models.HouseholdMember", b =>
                {
                    b.Property<int>("HouseholdMemberID")
                        .ValueGeneratedOnAdd();

                    b.Property<string>("DateOfBirth");

                    b.Property<int>("Gender");

                    b.Property<int>("Relationship");

                    b.Property<int?>("SubscriberID");

                    b.Property<int>("TobaccoUse");

                    b.HasKey("HouseholdMemberID");

                    b.HasIndex("SubscriberID");

                    b.ToTable("HouseholdMembers");
                });

            modelBuilder.Entity("Northwind.Insurance.Website.Models.InsurancePlan", b =>
                {
                    b.Property<int>("InsurancePlanId")
                        .ValueGeneratedOnAdd();

                    b.Property<double>("ERVisitAfterDeductible");

                    b.Property<double>("FamilyDeductible");

                    b.Property<double>("FamilyOutOfPocketMax");

                    b.Property<int>("FreePrimaryCareVisits");

                    b.Property<double>("IndividualDeductible");

                    b.Property<double>("IndividualOutOfPocketMax");

                    b.Property<bool>("IsSpecial");

                    b.Property<int>("Level");

                    b.Property<string>("PlanName");

                    b.Property<double>("Premium");

                    b.Property<double>("PrimaryCareVisitCostAfterDeductible");

                    b.HasKey("InsurancePlanId");

                    b.ToTable("InsurancePlans");
                });

            modelBuilder.Entity("Northwind.Insurance.Website.Models.Subscriber", b =>
                {
                    b.Property<int>("SubscriberID")
                        .ValueGeneratedOnAdd();

                    b.Property<string>("AddressLine1");

                    b.Property<string>("AddressLine2");

                    b.Property<double>("AlimonyChildSupport");

                    b.Property<string>("City");

                    b.Property<string>("County");

                    b.Property<string>("EmailAddress");

                    b.Property<double>("EmploymentIncome");

                    b.Property<string>("FirstName");

                    b.Property<double>("InvestmentIncome");

                    b.Property<bool>("IsMilitary");

                    b.Property<bool>("IsOnDisability");

                    b.Property<bool>("IsOnMedicare");

                    b.Property<bool>("IsStudent");

                    b.Property<bool>("IsUSCitizen");

                    b.Property<string>("LastName");

                    b.Property<string>("MiddleName");

                    b.Property<string>("PhoneNumber");

                    b.Property<string>("SocialSecurityNumber");

                    b.Property<string>("State");

                    b.Property<DateTime?>("TimeStamp");

                    b.Property<string>("ZipCode");

                    b.HasKey("SubscriberID");

                    b.ToTable("Subscribers");
                });

            modelBuilder.Entity("Northwind.Insurance.Website.Models.Enrollment", b =>
                {
                    b.HasOne("Northwind.Insurance.Website.Models.InsurancePlan", "InsurancePlan")
                        .WithMany("Enrollments")
                        .HasForeignKey("InsurancePlanID")
                        .OnDelete(DeleteBehavior.Cascade);

                    b.HasOne("Northwind.Insurance.Website.Models.Subscriber", "Subscriber")
                        .WithMany("Enrollments")
                        .HasForeignKey("SubscriberID")
                        .OnDelete(DeleteBehavior.Cascade);
                });

            modelBuilder.Entity("Northwind.Insurance.Website.Models.HouseholdMember", b =>
                {
                    b.HasOne("Northwind.Insurance.Website.Models.Subscriber")
                        .WithMany("HouseholdMembers")
                        .HasForeignKey("SubscriberID");
                });
        }
    }
}
