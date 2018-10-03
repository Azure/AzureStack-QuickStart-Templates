using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;

namespace Northwind.Insurance.Website.Models
{
    public static class InsuranceExtensions
    {
        public static void EnsureSeedData(this InsuranceContext context)
        {
            if (!context.Database.GetPendingMigrations().Any())
            {
                if (!context.InsurancePlans.Any())
                {
                    context.InsurancePlans.AddRange(
                        new InsurancePlan { PlanName = "Catastrophic", Premium = 163.88, IndividualDeductible = 7150.00, FamilyDeductible = 14350, IndividualOutOfPocketMax = 7150, FamilyOutOfPocketMax = 14300, ERVisitAfterDeductible = 0, FreePrimaryCareVisits = 3, PrimaryCareVisitCostAfterDeductible = 0, IsSpecial = false, Level = PlanLevel.Catastrophic },
                        new InsurancePlan { PlanName = "Bronze", Premium = 229.56, IndividualDeductible = 4500, FamilyDeductible = 9000, IndividualOutOfPocketMax = 7150, FamilyOutOfPocketMax = 14300, ERVisitAfterDeductible = 0, FreePrimaryCareVisits = 0, PrimaryCareVisitCostAfterDeductible = 35, IsSpecial = false, Level = PlanLevel.Bronze },
                        new InsurancePlan { PlanName = "Silver", Premium = 309.64, IndividualDeductible = 2500, FamilyDeductible = 5000, IndividualOutOfPocketMax = 7150, FamilyOutOfPocketMax = 14300, ERVisitAfterDeductible = 0, FreePrimaryCareVisits = 0, PrimaryCareVisitCostAfterDeductible = 25.00, IsSpecial = false, Level = PlanLevel.Silver },
                        new InsurancePlan { PlanName = "Gold", Premium = 386.34, IndividualDeductible = 750, FamilyDeductible = 1500, IndividualOutOfPocketMax = 4500, FamilyOutOfPocketMax = 9000, ERVisitAfterDeductible = 0, FreePrimaryCareVisits = 0, PrimaryCareVisitCostAfterDeductible = 15, IsSpecial = true, Level = PlanLevel.Gold });

                    context.SaveChanges();
                }
            }
        }
    }
}
