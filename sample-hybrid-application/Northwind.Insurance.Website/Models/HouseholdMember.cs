using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;

namespace Northwind.Insurance.Website.Models
{
    public enum Relationship
    {
        Applicant,
        Spouse,
        Dependent
    }

    public enum Gender
    {
        Male,
        Female,
        None
    }
    public enum TobaccoUse
    {
        Never,
        SixMonthsOrLess,
        SevenMonthsOrMore
    }
    public class HouseholdMember
    {
        public int HouseholdMemberID { get; set; }
        public Relationship Relationship { get; set; }
        public string DateOfBirth { get; set; }
        public Gender Gender { get; set; }
        public TobaccoUse TobaccoUse { get; set; }

    }
}
