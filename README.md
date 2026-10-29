# docker-osticket

# Introduction

Docker image for running version 1.18.4 of [OSTicket](http://osticket.com/).

This image has been created from the original docker-osticket image by [Petter A. Helset](mailto:petter@helset.eu).



It has a few modifications:

* Base OS image fixed to Alpine Linux
* AJAX issues fixed that made original image unusable
* Now designed to work with a linked [MySQL](https://registry.hub.docker.com/u/library/mysql/) docker container.
* Automates configuration file \& database installation
* EMail support
* 

OSTicket is being served by [nginx](http://wiki.nginx.org/Main) using [PHP-FPM](http://php-fpm.org/) with PHP 8.3.
[mail](http://php.net/manual/en/function.mail.php) function is configured to use [msmtp](http://msmtp.sourceforge.net/) to send out-going messages.

The `setup/` directory has been renamed as `setup\_hidden/` and the file system permissions deny nginx access to this
location. It was not removed as the setup files are required as part of the automatic configuration during container
start.

# Quick Start

Ensure you have a MySQL 5+ container running that OSTicket can use to store its data.

```bash
docker run --name osticket\_mysql -d -e MYSQL\_ROOT\_PASSWORD=secret -e MYSQL\_USER=osticket -e MYSQL\_PASSWORD=secret -e MYSQL\_DATABASE=osticket mysql:5
```

Now run this image and link the MySQL container.

```bash
docker run --name osticket -d --link osticket\_mysql:mysql -p 8080:80 campbellsoftwaresolutions/osticket
```

Wait for the installation to complete then browse to your OSTicket staff control panel at `http://localhost:8080/scp/`. Login with default admin user \& password:

* username: **ostadmin**
* password: **Admin1**

Now configure as required. If you are intending on using this image in production, please make sure you change the
passwords above and read the rest of this documentation!

Note (1): If you want to change the environmental database variables on the OSTicket image to run, you can do it as follows.

```bash
docker run --name osticket -d MYSQL\_ROOT\_PASSWORD=new\_root\_password -e MYSQL\_USER=new\_root\_user -e MYSQL\_PASSWORD=new\_secret -e MYSQL\_DATABASE=osticket --link osticket\_mysql:mysql -p 8080:80 campbellsoftwaresolutions/osticket
```

Note (2): OSTicket automatically redirects `http://localhost:8080/scp` to `http://localhost/scp/`. Either serve this on port 80 or don't omit the
trailing slash after `scp/`!

# MySQL connection

The recommended connection method is to link your MySQL container to this image with the alias name `mysql`. However, if you
are using an external MySQL server then you can specify the connection details using environmental variables.

OSTicket requires that the MySQL connection specifies a user with full permissions to the specified database. This is required for the automatic
database installation.

The OSTicket configuration file is re-created from the template every time the container is started. This ensures the
MySQL connection details are always kept up to date automatically in case of any changes.

## Linked container Settings

There are no mandatory settings required when you link your MySQL container with the alias `mysql` as per the quick start example.

## External MySQL connection settings

The following environmental variables should be set when connecting to an external MySQL server.

`MYSQL\_HOST`

The host name or IP address of the MySQL host to connect to. This is not required when you link a container
with the alias `mysql`. This must be provided if not using a linked container.

`MYSQL\_PORT`

The TCP port number to connect to on the MySQL host. This is only required if you are not using a linked container
and also are not using the default MySQL port on your server (3306).

`MYSQL\_PASSWORD`

The password for the specified user used when connecting to the MySQL server. By default will use the environmental variable
`MYSQL\_PASSWORD` from the linked MySQL container if this is not explicitly specified. This must be provided if not
using a linked container.

`MYSQL\_PREFIX`

The table prefix for this installation. Unlikely you will need to change this as customisable table prefixes are
designed for shared hosting with only a single MySQL database available. Defaults to 'ost\_'.

`MYSQL\_DATABASE`

The name of the database to connect to. Defaults to 'osticket'.

`MYSQL\_USER`

The user name to use when connecting to the MySQL server. Defaults to 'osticket'.

# Mail Configuration

The image does not run a MTA. Although one could be installed quite easily, getting the setup so that external mail servers
will accept mail from your host \& domain is not trivial due to anti-spam measures. This is additionally difficult to do
from ephemeral docker containers that run in a cloud where the host may change etc.

Hence this image supports OSTicket sending of mail by sending directly to designated a SMTP server.
However, you must provide the relevant SMTP settings through environmental variables before this will function.

To automatically collect email from an external IMAP or POP3 account, configure the settings for the relevant email address in
your admin control panel as normal (Admin Panel -> Emails).

## SMTP Settings

`SMTP\_HOST`

The host name (or IP address) of the SMTP server to send all outgoing mail through. Defaults to 'localhost'.

`SMTP\_PORT`

The TCP port to connect to on the server. Defaults to '25'. Usually one of 25, 465 or 587.

`SMTP\_FROM`

The envelope from address to use when sending email (note that is not the same as the From: header). This must be
provided for sending mail to function. However, if not specified, this will default to the value of `SMTP\_USER` if this is provided.

`SMTP\_TLS`

Boolean (1 or 0) value indicating if TLS should be used to create a secure connection to the server. Defaults to true.

`SMTP\_TLS\_CERTS`

If TLS is in use, indicates file containing root certificates used to verify server certificate. Defaults to system
installed ca certificates list. This would normally only need changed if you are using your own certificate authority
or are connecting to a server with a self signed certificate.

`SMTP\_USER`

The user identity to use for SMTP authentication. Specifying a value here will enable SMTP authentication. This will also
be used for the `SMTP\_FROM` value if this is not explicitly specified. Defaults to no value.

`SMTP\_PASSWORD`

The password associated with the user for SMTP authentication. Defaults to no value.

## IMAP/POP3 Settings

`CRON\_INTERVAL`

Specifies how often (in minutes) that OSTicket cron script should be ran to check for incoming emails. Defaults to 5
minutes. Set to 0 to disable running of cron script. Note that this works in conjuction with the email check interval
specified in the admin control panel, you need to specify both to the value you'd like!

# Volumes

This image currently supports three volumes. None of these need to used if you do not require them.

`/data/upload/include/plugins`

This is the location where any OSTicket plugins, like [the core plugins](https://github.com/osTicket/core-plugins),
can be placed. Standard Plugins are not included in this image and hence should be maintained in a separate linked Docker
container or the host filesystem.

`/data/upload/include/i18n`

This is the location where language packs can be added. There are several languages included in this image.
If you want to add / change them, you can use this volume.

`/var/log/nginx`

nginx will store it's access \& error logs in this location. If you wish to expose these to automatic log
collection tools then you should mount this volume.

# Environmental Variables

`INSTALL\_SECRET`

Secret string value for OST installation. A random value is generated on start-up and persisted within the container if this is not provided.

*If using in production you should specify this so that re-creating the container does not cause
your installation secret to be lost!*

`INSTALL\_CONFIG`

If you require a configuration file for OSTicket with custom content then you should create one and mount it in your
container as a volume. The placeholders for the MySQL connection must be retained as these will be populated automatically
when the container starts. Set this environmental variable to the fully qualified file name of your custom configuration.
If not specified, the default OSTicket sample configuration file is used.

`INSTALL\_EMAIL`

Helpdesk email account. This is placed in the configuration file as well as the DB during installation.
Defaults to 'helpdesk@example.com'

`INSTALL\_URL`

The full URL of the OST ticket installation that will be set in the DB during installation.
This should be set to match the public facing URL of your OSTicket site.
For example: `https://help.example.com/osticket`. Defaults to `http://localhost:8080/`.

This has no effect if the database has already been installed. In this case, you should change the Helpdesk URL in
*System Settings and Preferences* in the admin control panel.
---

## 

## Database Installation Only

The remaining environmental variables can be used as a convenience to provide defaults during the automated database
installation but most of these settings can be changed through the admin panel if required. These are only used when creating
the initial database.

`INSTALL\_NAME`

The name of the helpdesk to create if installing. Defaults to "My Helpdesk".

`ADMIN\_FIRSTNAME`

First name of automatically created administrative user. Defaults to 'Admin'.

`ADMIN\_LASTNAME`

Last name of automatically created administrative user. Defaults to 'User'.

`ADMIN\_EMAIL`

Email address of automatically created administrative user. Defaults to 'admin@example.com'.

`ADMIN\_USERNAME`

User name to use for automatically created administrative user. Defaults to 'ostadmin'.

`ADMIN\_PASSWORD`

Password to use for automatically created administrative user. Defaults to 'Admin1'.

# 

# Modifications

This image was put together relatively quickly and could probably be improved to meet other use cases for my specific needs and to significantly ease updates for myself. I've published all my changes so that they may be of use to others, but I do not typically have time to support the image for others or provide any technical assistance.

# 

# Patches and Plugins

To make OSTicket more friendly to my specific needs and team we have produced the following patches and plugins. The target for this was to use the wonderful Plug-In environment such that future upgrades don't affect the main source of the project. Where that wasn't possible some small patches are used to implement the changes.



* The plugin lives in its own folder and survives upgrades.





## UI Patch



|Change|Files Touched|Status|
|-|-|-|
|<br />Show Full-width staff panel (ticket list, ticket view and other pages fill the browser instead of original fixed 960px).<br /><br />Reply / Note / Task-update editors, start at 300px tall and can be resized by dragging their bottom-right corner|`scp/css/custom.css` (new), `include/staff/header.inc.php` (+1 line)|Tested on backup production instance of 1.17.8 and 1.18.4|
|"Inactive" ticket status: treated as vclosed but not "completed"; own queue, kept out of the Closed queue<br /><br />Solves case of an item that is a 'wont-fix' for now - them problem is known, solution is planned, but work is not complete and don't want it to be lost should this become active again one day.<br />No code — admin configuration (steps below)|No code — admin configuration only (steps below)|Tested on backup production instance of 1.17.8 and 1.18.4|
|"My Tickets" Queue can now  include tickets where you are a collaborator: new **Assignee** choice *Me (as collaborator)* for queues and searches|`include/class.search.php` (core edit)|Tested on backup production instance of 1.17.8 and 1.18.4|



## Custom Plugins



|Change|Files Touched|Status|
|-|-|-|
|**Time \& Cost Tracking plugin**: Time/Cost inputs on Post Reply and Post Internal Note, logged per post, rolled up into the ticket's Time/Cost fields<br /><br />Count-up timer in the Time box on every ticket and task, rounded up to a configurable step when posting.<br /><br />Times for subtasks are automatically rolled into the parent ticket<br /><br />Time \& Cost breakdown per task: a "Time \& Cost" panel on the ticket (ticket's own time, each task, total) and Time / Cost columns on the ticket's Tasks tab<br><br>Time reports - Every Agent can view their own time and cost for various periods or custom dates as a list or timesheet grid, Excel/CSV exportable and a print layout. Managers can view agents in department, Admin can view any agent.|`scp/css/custom.css` (new), `include/staff/header.inc.php` (+1 line)|Tested on backup production instance of 1.17.8 and 1.18.4|
|**Search Plus plugin:<br />**better ticket and task keyword search (all words must match, no minimum length, substring + `\\\*` wildcards, phrases, exclusions; up to 8 words instead of 3)<br /><br />Cross-search between tickets and tasks:<br />Ticket searches also match the ticket's tasks; Task searches also match the|`include/plugins/search-plus/` (new), `include/staff/tasks.inc.php` (task-search hook), `scp/tickets.php` (word limit)|Tested on backup production instance of 1.17.8 and 1.18.4|
|**Task Statuses plugin:<br />**Tasks get their own named statuses (Open, In Progress, Waiting on Parts, Completed, Inactive…), each mapped to open or closed<br /><br />Named task statuses in the task's **Change Status** menu (flag button), the **Actions** menu of a task opened inside a ticket, and the clickable Status in the task header|`include/plugins/task-status/` (new), `include/class.task.php` (status-name hook), `include/staff/tasks.inc.php` (Status column), `include/staff/ticket-tasks.inc.php` (ticket's Tasks tab)|Tested on backup production instance of 1.17.8 and 1.18.4|
|Convert Ticket to Task plugin:<br />Adds "Convert to Task" on the ticket **More** menu turns a ticket into a task of another ticket<br />Solves case of a ticket being created that should have been a task of an existing ticket.|`include/plugins/ticket-to-task/` (new; no core edits)|Tested on backup production instance of 1.17.8 and 1.18.4|





### Plug-in Instructions



##### Time \& Cost Tracking Plugin — setup

1. Apply the patch (or copy `include/plugins/time-tracking/` into your install).
2. **Admin Panel → Manage → Plugins → Add New Plugin → Time \& Cost Tracking → Install**, then open it, go to **Instances → Add New Instance**, enable it, and set:

   * **Time field variable** / **Cost field variable**: the *Variable* name of your ticket-form fields (default `time` / `cost`).
   * **Task time / cost field variable**: the *Variable* names on your task form, e.g. *Task Details* (default `time` / `cost`).
   * **Time total format**: decimal hours (`1.50`) or `h:mm` (`1:30`).
   * **Currency symbol**: used only for display.
   * **Count-up timer** (on by default) and **Round timer up to**: next minute, 0.1 h (default), 0.25 h, 0.5 h or 1 h.
3. **Admin Panel → Manage → Forms → (your ticket form and Task Details) → Time / Cost → Config → Visibility**: leave agent **View** on and turn agent **Edit** off, so the fields work as read-only totals.



###### How it works

* The Post Reply and Post Internal Note forms get a **Time / Cost** row above Ticket Status. Both inputs are optional.
* Time accepts `1.5`, `1:30`, `1h 30m`, `45m`, `2h`. A plain number means hours. Cost accepts `75`, `75.50`, `$1,250.00`.
* **Timer:** on every ticket and task page, including a task opened inside a ticket, the Time box counts up (green, `h:mm:ss`) from when the page was opened.

  * When you post a reply, update or note, the timed value is **rounded up** to the configured step and logged. For example, 7 min 15 s becomes 0.2 h with the 0.1 h setting.
  * After posting, the timer starts again from zero.
  * **Pause / resume** with the ⏸ button and **restart from zero** with ↻. Ticket and task timers run separately.
  * **Click into the box** to take over: it shows the rounded value, selected, so you can type a different time. Clear it to post with no time. Typed times are not rounded.
  * If a post fails (e.g. missing text), the value is kept and the timer stops for that box.
* Negative values (`-0.25`, `-10`) are allowed for corrections, since thread posts can't be deleted.
* Invalid input is caught in the browser before posting. If a post fails for another reason (e.g. empty response), the values you typed are kept.
* Each post with a value is saved in a new table, `ost\\\_time\\\_cost\\\_entry`, which the plugin creates itself. Each row holds what it was logged on (ticket or task), the parent ticket, thread entry, agent, minutes, cost and date.
* Totals are **recomputed from the log** after every post, so they never drift. They also stay searchable and usable as queue columns.

  * **Task** Time/Cost = that task's own entries.
  * **Ticket** Time/Cost = the ticket's own entries + the entries of all its tasks.
  * A standalone task (not linked to a ticket) keeps its own total only.
* Tasks work both on the Tasks page and when a task is opened inside a ticket. After posting on a task inside a ticket, the ticket's total shown at the top of the page updates on the next page refresh.
* **Opening balance:** a value already typed into a ticket's or task's Time/Cost field is imported as an "opening" row the first time an entry is logged on it.
* **Deleting a task** removes its entries and recalculates the parent ticket's totals.
* Thread entries with logged time/cost show a small badge in their header, e.g. `0.75 h · $15.00`.
* Time/cost on a **Post Reply** is internal. It is never added to the email or message the customer sees.
* **Time and Cost Summary:** once anything is logged, the ticket page shows a **Time \& Cost** panel above the Thread / Tasks tabs.

  * It has one row for the ticket's own time, one row per task (with its status and a link to it), and a **Total** row. The total matches the ticket's Time / Cost fields.
  * The ticket's **Tasks** tab gains **Time** and **Cost** columns.
  * Both update straight away after you post time on a task opened inside the ticket and go back to **All Tasks**.
  * Tickets with nothing logged show no panel.



#### Search Plus Plugin— setup

1. Apply the patch.
2. **Admin Panel → Manage → Plugins → Add New Plugin → Search Plus → Install**, then add an instance and enable it. Settings: ticket search on/off, task search on/off, cross-search on/off, and the maximum number of search words (default 8).
3. Make sure the osTicket cron job is running. The search uses osTicket's existing search index, and cron fills it in for older content.

## 

###### How searching works

|You type|Finds|
|-|-|
|`printer jam`|tickets containing **both** words, in any order, anywhere in the ticket|
|`ab`, `X7`|short words work (no 3-letter minimum)|
|`rint`|matches inside words ("printer")|
|`PN\\\*100`|`\\\*` = any characters (PN-100, PN2100); `?` = one character|
|`123-4567`|part/serial numbers with dashes|
|`"display flickers"`|exact phrase|
|`printer -laser`|`-` excludes tickets containing a word|

* **Tickets:** searches the subject and number, every thread entry, custom fields, and the requester's name and email. A ticket matches when every word appears somewhere in it, even in different posts. This applies to the staff search box, Advanced Search → Keywords, the search typeahead, and the client portal search.
* **Tasks:** searches task number, task form fields (title, etc.) and the task's thread entries, with the same rules. Stock osTicket only matched the whole query against the title or number.
* **Cross-search (ON by default, setting in PluginAdmin is *Cross-search tickets and tasks*):**

  * **Ticket searches** also look at the ticket's tasks: their titles and other task fields, and every task update and note. Example: `Power connector` finds a ticket whose subject says Power and whose task note says connector.
  * **Task searches** also look at the parent ticket: its number, subject, custom fields and whole thread. A word that appears only in the ticket therefore matches *all* of that ticket's tasks.
  * `-word` exclusions apply across both. A ticket is left out if any of its tasks contains the word.
  * The **client portal is not affected**, because tasks are internal. Customers' searches never match task content.
* Matching ignores case and accents. Results are sorted by how many times the words match.
* Disabling the plugin restores stock search. The core edits fall back to the original behavior automatically.



###### Performance

Substring search reads the whole search index rather than using MySQL's word index. Speeds on a test database of 20,000 tickets and 200,000 thread entries:



|Search|Search Plus|Stock|
|-|-|-|
|Typical search|about 1.5–3 s|—|
|Unusual words, multi-word phrases with exclusions|up to about 6 s|—|
|Common two-word search|under 5 s|31 s|
|Rare word|under 2 s|0.05 s|



Search time grows with the size of the index. A faster "word-start" mode that uses MySQL's word index is possible if a much larger database needs it.



#### Task Status Plugin — setup

1. Apply the patch.
2. **Admin Panel → Manage → Plugins → Add New Plugin → Task Statuses → Install**.
3. Open the plugin and set **Status: Active**. Then go to **Instances → Add New Instance**:

   * Give it a name.
   * Set **Status: Enabled**.
   * On the **Config** tab, edit the list, one status per line as `Name | open` or `Name | closed`. The default list is:

&#x20;    `Open | open In Progress | open Waiting on Parts | open Completed | closed Inactive | closed`

* The first *open* status is used for new or reopened tasks.
* The first *closed* status is used when a task is closed without choosing a status, e.g. with the Close button or a bulk close.
* The list must contain at least one open and one closed status.

###### 

###### How it works

* The **Status** drop-down on a task's **Post Update** and **Post Internal Note** lists your statuses instead of Open / Closed.

  * Choosing an open status (e.g. Open → In Progress) keeps the task open.
  * Choosing a closed status (Completed or Inactive) closes it.
  * Closed statuses only appear when the agent is allowed to close the task, the same rule as stock.
* The named status is shown in four places:

  * the task header
  * the ticket's **Tasks** tab
  * a new **Status** column on the Tasks list
  * task preview and print
* Inactive tasks are listed under the **Closed** tasks filter, with "Inactive" in the Status column.
* **Change Status menu:** the task's flag button (or **Actions** when the task is opened inside a ticket) lists every status except the current one. Clicking the **Status** value in the task header opens the same menu.

  * Choosing one switches immediately, and opens or closes the task when needed.
  * It adds an internal note "Status changed from X to Y".
  * Closed statuses are offered only to agents allowed to close the task. If the task can't be closed, a message explains why.
* Bulk close/reopen from the Tasks list (and closing the parent ticket) sets the first closed or first open status.
* The status is stored in a new table, `ost\\\_task\\\_status`, which the plugin creates itself.
* If the plugin is disabled, tasks show stock Open / Completed again. If it is turned back on later, any task whose saved status no longer matches its open/closed state shows the default status for that state.



## Convert Ticket to Task Plugin — setup

1. Apply the patch.
2. **Admin Panel → Manage → Plugins → Add New Plugin → Convert Ticket to Task → Install**.
3. Set the plugin to **Active**, then add an instance and enable it. The one setting, **Allow deleting the original**, is on by default.


How it works
---

**Opening the dialog.** Open the ticket, click **More**, then **Convert to Task**. It appears just above Delete Ticket.

**What you fill in:**

* **Target ticket number.** As you type, the dialog shows that ticket's subject and status. It warns if the number is this ticket, doesn't exist, or you can't add tasks to it.
* **Task title.** Defaults to the ticket subject.
* **Department.** Defaults to the target ticket's department.
* **This ticket.** Either *Close it* with a closed-type status you pick (Closed, Resolved, Inactive…), or *Delete it*.



**What Convert does:**

1. Creates the task on the target ticket, assigned to the same agent as the original ticket. The task's first entry says where it came from: original number, subject, customer, date, and who converted it.
2. Copies **every message, reply and internal note** into the task, with the original author, date, reply-to links and **attachments**.

   * Copied entries are searchable immediately.
   * System events, such as "assigned" or "status changed", are not copied.
3. **Always adds the original customer and its collaborators** to the target ticket as collaborators. The target ticket's own owner is skipped.
4. Moves any tasks the original ticket had to the target ticket.
5. Moves logged **Time \& Cost** to the new task. Totals are recalculated for the task, the target ticket (which now includes it) and the original ticket.
6. Adds an internal note on the target ticket ("Ticket #… was converted to task #…").
7. Then either closes the original with an internal note linking to the task, or deletes it. Deleting does not lose attachments, because the task's copies keep the files.
8. Opens the new task.



**Who sees it.** The menu item is shown only to agents who may close or delete the ticket. Merged tickets (parent or child) can't be converted.





## My Tickets — Collaborator Visibility setup (patch)

1. Apply the patch. The Assignee choice list in queues and Advanced Search gains **Me (as collaborator)**. It matches open tickets where the logged-in agent's email address is an *active* collaborator.
2. **Admin Panel → Settings → Tickets → Queues → My Tickets**: in the **Assignee** criterion (*is*), also tick **Me (as collaborator)** → Save. The queue is now *assigned to me* OR *one of my teams* OR *I'm a collaborator*.
3. Optional, to keep the sub-queues tidy:

   * Add a sub-queue under My Tickets called **Collaborating**, with the criterion Assignee *is* **Me (as collaborator)**.
   * Edit **Assigned to Teams** so its criterion is Assignee *is not* **Me** and **Me (as collaborator)**. Otherwise collaborator tickets also show up there.

Notes:

* osTicket collaborators are contacts (users), not agents. A ticket matches when a collaborator's email address is the same as the agent's email address in their agent profile, e.g. when the agent was CC'd.
* Collaborators turned off on a ticket (unticked in Manage Collaborators) don't count.
* Normal access rules still apply. The agent only sees collaborator tickets in departments they can access, or tickets referred to them.





# License

This image and source code is made available under the MIT licence. See the LICENSE file for details.

