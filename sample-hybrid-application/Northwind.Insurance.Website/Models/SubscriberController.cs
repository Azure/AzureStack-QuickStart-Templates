using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace Northwind.Insurance.Website.Models
{
    public class SubscriberController : Controller
    {
        // GET: Subscriber
        public ActionResult Index()
        {
            return View();
        }

        // GET: Subscriber/Details/5
        public ActionResult Details(int id)
        {
            return View();
        }

        // GET: Subscriber/Create
        public ActionResult Create()
        {
            return View();
        }

        // POST: Subscriber/Create
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Create(IFormCollection collection)
        {
            try
            {
                // TODO: Add insert logic here

                return RedirectToAction("Index");
            }
            catch
            {
                return View();
            }
        }

        // GET: Subscriber/Edit/5
        public ActionResult Edit(int id)
        {
            return View();
        }

        // POST: Subscriber/Edit/5
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Edit(int id, IFormCollection collection)
        {
            try
            {
                // TODO: Add update logic here

                return RedirectToAction("Index");
            }
            catch
            {
                return View();
            }
        }

        // GET: Subscriber/Delete/5
        public ActionResult Delete(int id)
        {
            return View();
        }

        // POST: Subscriber/Delete/5
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Delete(int id, IFormCollection collection)
        {
            try
            {
                // TODO: Add delete logic here

                return RedirectToAction("Index");
            }
            catch
            {
                return View();
            }
        }
    }
}