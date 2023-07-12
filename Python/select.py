import psycopg2

# Define the database connection parameters

def select_data(conn: psycopg2.extensions.connection):
    while True:
        ip_address = input("input IP address: ")
        with conn.cursor() as cursor:
            cursor.execute('''
        SELECT i.ip, it.site, it.url, it.organization, it.delo, it.delo_date
        FROM ips i
        JOIN items it ON i.item_id = it.item_id
        WHERE i.ip = %s
        ''', (ip_address,))
            results = cursor.fetchall()
            
        with conn.cursor() as cursor:
            cursor.execute('''
        SELECT COUNT(*)
        FROM ips
        ''', (ip_address,))
            total_ip_count = cursor.fetchone()[0]
            
        with conn.cursor() as cursor:
            cursor.execute('''
        SELECT COUNT(*)
        from items
        ''', (ip_address,))
            total_item_count = cursor.fetchone()[0]
            
        with conn.cursor() as cursor:
            cursor.execute('''
        SELECT COUNT(*)
        FROM ips i
        WHERE i.ip = %s
        ''', (ip_address,))
            ip_count = cursor.fetchone()[0]
            
            if len(results) > 0:
                print("Total number of IPs: " + str(total_ip_count))
                print("Total number of domains: " + str(total_item_count))
                print("Results for IP Address: " + ip_address)
                print(f"Number results for {ip_address}: {str(ip_count)}")
                print("IP Address | Site | URL | Organization | Delo | Date")
                for result in results:
                    print(result[0] + " | " + result[1] + " | " + result[2] + " | " + result[3] + " | " + result[4] + " | " + result[5].strftime("%Y-%m-%d"))
            else:
                print("No results found for IP Address: " + ip_address)
        if input("Continue? y/n: ") == 'n':
            break

if __name__ == '__main__':
    db = 'session5'
    user = 'user'
    passwd = '1234'
    host = '0.0.0.0'
    port = '5432'
    try:
        with psycopg2.connect(database=db, user=user, password=passwd, host=host, port=port) as connection:
                select_data(connection)
    except psycopg2.OperationalError:
            print("Failed to connect to the database")
