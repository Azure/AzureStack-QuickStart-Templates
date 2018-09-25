using System;
using System.Net;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Northwind.Insurance.Website.Models;

namespace Northwind.Insurance.Website.Controllers
{
    public class HomeController : Controller
    {
        private readonly InsuranceContext _context;

        public HomeController (InsuranceContext context)
        {
            _context = context;
        }
        public IActionResult Index()
        {
            ViewData["ActivePage"] = "home";
            ViewData["Title"] = "Northwind Insurance";
            HttpContext.Session.SetString("CloudName", IsAzureOrAzureStack());
            return View();
        }

        public IActionResult ApplyNow()
        {
            ViewData["ActivePage"] = "applynow";
            ViewData["Title"] = "Northwind Insurance - Application";
            return View();
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> CreateApplication(
            [Bind("ZipCode,EmploymentIncome,HouseholdMembers")] Subscriber _subscriber)
        {
            try
            {
                if(ModelState.IsValid)
                {
                    _subscriber.TimeStamp = DateTime.Now;
                    _context.Add(_subscriber);
                    await _context.SaveChangesAsync();
                    TempData["SubscriberId"] = _subscriber.SubscriberID;
                    return RedirectToRoute("showplans");
                }
            }
            catch (DbUpdateException ex)
            {
                ModelState.AddModelError("", "Unable to save changes. " +
            "Try again, and if the problem persists " +
            "see your system administrator." + ex.Message);
            }
            return View(_subscriber);
        }

        public IActionResult Error()
        {
            return View();
        }

        //Returns true if running on Azure, false if on Azure Stack
        public string IsAzureOrAzureStack()
        {
            /*var addresses = Dns.GetHostAddresses(Dns.GetHostName());
            foreach(var address in addresses)
            {
                if(address.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork && address.GetAddressBytes()[0] != 127)
                {
                    if (address.GetAddressBytes()[0] == 10 && address.GetAddressBytes()[2] < 3)
                    {
                        return "AZURE STACK";
                    }
                    else if (address.GetAddressBytes()[0] == 10 && address.GetAddressBytes()[2] >= 3 && address.GetAddressBytes()[2] < 6)
                    {
                        return "AZURE";
                    }
                    else
                    {
                        return Dns.GetHostName().ToString();
                    }
                }
            }*/

            if(Environment.GetEnvironmentVariable("WEBSITE_HOSTNAME").Contains("azurewebsites.net"))
            {
                return "AZURE";
            }
            else
            {
                return "AZURE STACK";
            }


            //return Environment.GetEnvironmentVariable("WEBSITE_HOSTNAME");
        }
    }
}
