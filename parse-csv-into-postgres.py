import csv
import psycopg2
import logging 


def parse_dump(filename: str) -> list:
    with open(filename, encoding='windows-1251') as csvfile:
        reader = csv.reader(csvfile, delimiter=';')
        result = [row for row in reader][1:]
        csvfile.close() 
        print(f"parsed {len(result)} lines from {filename}")
        return result


def create_tables(conn: psycopg2.extensions.connection):
    with conn.cursor() as cursor:
        cursor.execute('''
    CREATE TABLE IF NOT EXISTS
        items (
            item_id INTEGER PRIMARY KEY,
            site text,
            url text,
            organization text,
            delo text,
            delo_date date
        )
    ''')
        cursor.close()
        print("created items table")
    with conn.cursor() as cursor:
        cursor.execute('''
    CREATE TABLE IF NOT EXISTS
        ips (
            ip_id SERIAL PRIMARY KEY,
            ip text,
            item_id INTEGER REFERENCES items(item_id)
        )
    ''')
        cursor.close()
        print("created ips table")


def insert_data(conn: psycopg2.extensions.connection, rows: list):
    with conn.cursor() as cursor:
        items = []
        for item_id, row in enumerate(rows):
            items.append([item_id, *row[1:]])
            #print(item_id)
        cursor.executemany('''
    INSERT INTO
        items(
            item_id, site, url, organization, delo, delo_date
        )
    VALUES
        (%s, %s, %s, %s, %s, %s)
    ''', items)
        #cursor.commit()
        cursor.close()
        print("executed many #1")
        ips = []
        for item_id, row in enumerate(rows):
            item_ips = [[item_id, ip] for ip in row[0].split('|')]
            ips.extend(item_ips)
    with conn.cursor() as cursor:
        cursor.executemany('''
    INSERT INTO
        ips(
            item_id, ip
        )
    VALUES
        (%s, %s)
    ''', ips)
        print("executed many #2")
        #cursor.commit()
        cursor.close()
        print(f'Inserted {len(items)} items and {len(ips)} ips')

if __name__ == '__main__':
    csv.field_size_limit(15000000)
    rows = parse_dump('dump.csv')
    db = 'session5'
    user = 'user'
    passwd = '1234'
    host = '0.0.0.0'
    port = '5432'
    # logging.basicConfig(filename='parse-csv-into-postgres.log', level=print)
    print(f"connecting to {db} database with credentials: {user}:{passwd}@{host}:{port}")
    try:
        with psycopg2.connect(database=db, user=user, password=passwd, host=host, port=port) as connection:
            create_tables(connection)
            insert_data(connection, rows)
            connection.commit()
            connection.close()
    except psycopg2.OperationalError:
        print("Failed to connect to the database")