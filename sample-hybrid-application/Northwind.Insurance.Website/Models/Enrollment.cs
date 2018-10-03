using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;

namespace Northwind.Insurance.Website.Models
{
    public class Enrollment
    {
        public int EnrollmentID { get; set; }
        public int InsurancePlanID { get; set; }
        public int SubscriberID { get; set; }
        public int PlanYear { get; set; }
        public string ConfirmationCode { get; set; }
        public virtual InsurancePlan InsurancePlan { get; set; }
        public virtual Subscriber Subscriber { get; set; }
        public DateTime? TimeStamp { get; set; }

    }
}
