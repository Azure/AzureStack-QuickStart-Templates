using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations.Schema;

namespace Northwind.Insurance.Website.Models
{
    public class Subscriber
    {
        public int SubscriberID { get; set; }
        public string FirstName { get; set; }
        public string MiddleName { get; set; }
        public string LastName { get; set; }
        public string AddressLine1 { get; set; }
        public string AddressLine2 { get; set; }
        public string City { get; set; }
        public string State { get; set; }
        public string ZipCode { get; set; }
        public string County { get; set; }
        public string PhoneNumber { get; set; }
        public string EmailAddress { get; set; }
        public string SocialSecurityNumber { get; set; }
        public bool IsUSCitizen { get; set; }
        public bool IsMilitary { get; set; }
        public bool IsStudent { get; set; }
        public bool IsOnMedicare { get; set; }
        public bool IsOnDisability { get; set; }
        public double EmploymentIncome { get; set; }
        public double InvestmentIncome { get; set; }
        public double AlimonyChildSupport { get; set; }
        public virtual ICollection<HouseholdMember> HouseholdMembers { get; set; }
        public virtual ICollection<Enrollment> Enrollments { get; set; }
        public DateTime? TimeStamp { get; set; }

        public Subscriber()
        {

            IsUSCitizen = true;
            IsMilitary = false;
            IsStudent = false;
            IsOnDisability = false;
            IsOnMedicare = false;
        }
        
    }
}
