
import requests
import BeautifulSoup
import pymongo

import datetime


########### Get data
response = requests.get("http://hraun.vedur.is/ja/skjalftar/skjlisti.html")

data = []

if response.status_code == 200:
    ########### Parse data
    parsed_html = BeautifulSoup.BeautifulSoup(response.text)

    first = True
    for table_row in parsed_html.body.findAll("table")[2].findAll("tr"):
        # skip the header line
        if first:
            first = False
            continue

        day, time, latitude, longitude, depth, size, quality, location_dist, location_dir, location_name = table_row.findAll("td")
        day = day.text
        time, subsecond = time.text.split(",")
        subsecond = float("0."+subsecond)

        date_object = datetime.datetime.strptime("%s %s %06d" % (day, time, subsecond*1000000), '%Y-%m-%d %H:%M:%S %f')

        latitude = float(latitude.text.replace(",", "."))
        longitude = float(longitude.text.replace(",", "."))
        depth = float(depth.text.replace(",", "."))
        size = float(size.text.replace(",", "."))
        quality = float(quality.text.replace(",", "."))
        location_dist = location_dist.text
        location_dir = location_dir.text
        location_name = location_name.text

        data_row = {
            "date": date_object,
            "latitude": latitude,
            "longitude": longitude,
            "depth": depth,
            "size": size,
            "quality": quality,
            "location_dist": location_dist,
            "location_dir": location_dir,
            "location_name": location_name,
            #"verified": False,
        }
        data.append(data_row)
else:
    print "Failed to get new data from hraun.vedur.is"



####### get data corrections from when humans have corrected it
verified_data = []
response = requests.get("http://www.vedur.is/skjalftar-og-eldgos/jardskjalftar#view=table")
if response.status_code == 200:

    js_data_dict_string = response.text.split("VI.quakeInfo = [", 1)[1].split("];\n", 1)[0]

    for row in js_data_dict_string.split("},"):
        singlequote_split = row.split("'")
        date = singlequote_split[2][10:-2]
        date_object = datetime.datetime.strptime(date, '%Y,%m-1,%d,%H,%M,%S')
        a = float(singlequote_split[5])
        latitude = float(singlequote_split[9].replace(",", "."))
        longitude = float(singlequote_split[13].replace(",", "."))
        depth = float(singlequote_split[17].replace(",", "."))
        size = float(singlequote_split[21].replace(",", "."))

        quality = float(singlequote_split[25].replace(",", "."))
        location_dist = float(singlequote_split[29].replace(",", "."))
        location_dir = singlequote_split[33].rstrip()
        location_name = singlequote_split[37]

        data_row = {
            "date": date_object,
            "latitude": latitude,
            "longitude": longitude,
            "depth": depth,
            "size": size,
            "quality": quality,
            "location_dist": location_dist,
            "location_dir": location_dir,
            "location_name": location_name,
            "verified": True,
        }
        verified_data.append(data_row)

else:
    print "failed to get new data from www.vedur.is/skjalftar-og-eldgos"


##############################
# setup mongodb connection
client = pymongo.MongoClient("localhost", 27017)
isapi_db = client.isapi
earthquake_collection = isapi_db.earthquake
earthquake_collection.ensure_index("date")

# insert or update all the found rows, but only if they were
inserts = 0
for data_row in data:
    found_rows = earthquake_collection.find(
        {"date": data_row["date"]}
    )
    if found_rows.count() > 1:
        continue
    if found_rows.count() == 0:
        earthquake_collection.save(data_row)
        inserts += 1

print "Inserted", inserts, "unverified rows"


# insert or update all the found rows, but only if they were
verified_refreshes = 0
verified_inserts = 0
for data_row in verified_data:

    start_time = data_row["date"]
    # cap it at whole seconds
    start_time = datetime.datetime(start_time.year, start_time.month, start_time.day, start_time.hour, start_time.minute, start_time.second)
    end_time = start_time + datetime.timedelta(seconds=1)
    found_rows = earthquake_collection.find(
        {
            "date": {
                "$gte": start_time,
                "$lt": end_time,
            },
        }
    )
    if found_rows.count() > 1:
        row_dates = []
        for row in found_rows:
            row_dates.append(row["date"])
        print "skipping count as there are", found_rows.count(), " rows for", start_time, end_time, row_dates
        continue

    # a new one we have not seen before insert it
    if found_rows.count() == 0:
        earthquake_collection.save(data_row)
        verified_inserts += 1
        #print "inserted at", data_row["date"], "size", data_row["size"]
    else:
        found_row = found_rows[0]
        # if we already have verified it just skip it
        if found_row.get("verified", False):
            continue
        # count it one so update
        # remove teh date as it has less precision here
        data_row["date"] = found_row["date"]
        changed_row = earthquake_collection.update(
            {"_id": found_row["_id"]},
            data_row
        )
        verified_refreshes += 1

print "Updated", verified_refreshes, "verified rows"
print "Inserted", verified_inserts, "verified rows"



client.close()



#import time
# debug print out all the rows in the db
#for row in earthquake_collection.find():
#    print row["date"], row["latitude"], row["longitude"], row["size"]
#    unix_time = time.mktime(row["date"].timetuple())
#    print unix_time
#    break

