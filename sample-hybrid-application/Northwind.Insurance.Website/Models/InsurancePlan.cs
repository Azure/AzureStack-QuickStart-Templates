using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;

namespace Northwind.Insurance.Website.Models
{
    public class InsurancePlan
    {
        public int InsurancePlanId { get; set; }
        public string PlanName { get; set; }
        public double Premium { get; set; }
        public double IndividualDeductible { get; set; }
        public double FamilyDeductible { get; set; }
        public double IndividualOutOfPocketMax { get; set; }
        public double FamilyOutOfPocketMax { get; set; }
        public double ERVisitAfterDeductible { get; set; }
        public int FreePrimaryCareVisits { get; set; }
        public double PrimaryCareVisitCostAfterDeductible { get; set; }
        public bool IsSpecial { get; set; }
        public PlanLevel Level { get; set; }
        public virtual ICollection<Enrollment> Enrollments { get; set; }
    }
}
