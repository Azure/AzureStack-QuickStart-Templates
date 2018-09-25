using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;

namespace Northwind.Insurance.Website.Models
{
    public class InsuranceContext : DbContext
    {
        public InsuranceContext(DbContextOptions<InsuranceContext> options) : base(options)
        {

        }

        public DbSet<InsurancePlan> InsurancePlans { get; set; }
        public DbSet<Enrollment> Enrollments { get; set; }
        public DbSet<Subscriber> Subscribers { get; set; }
        public DbSet<HouseholdMember> HouseholdMembers { get; set; }

    }
}
