import csv
import psycopg2 
import queries


def parse_dump(filename: str) -> list:
    with open(filename, encoding='windows-1251') as csvfile:
        reader = csv.reader(csvfile, delimiter=';')
        next(reader) # skip line with 'Updated: 2023-05-04 13:25:00 +0000'
        return [row for row in reader]


def create_tables(conn: psycopg2.extensions.connection):
    with conn.cursor() as cur:
        cur.execute(queries.create_violations)
    with conn.cursor() as cur:
        cur.execute(queries.create_ips)


def insert_data(conn: psycopg2.extensions.connection, rows: list):
    violations = [(violation_id, *row[1:]) for violation_id, row in enumerate(rows, 1)]
    with conn.cursor() as cur:
        cur.executemany(queries.insert_violation, violations)
    ips = []
    for violation_id, row in enumerate(rows, 1):
        violation_ips = [(violation_id, ip) for ip in row[0].split('|')]
        ips.extend(violation_ips)
    with conn.cursor() as cur:
        cur.executemany(queries.insert_ip, ips)


if __name__ == '__main__':
    csv.field_size_limit(10485760)  # set maximum field size to 10 MB
    rows = parse_dump('dump.csv')
    with psycopg2.connect(dsn='postgresql://myuser:mypassword@localhost:5432/zapret') as conn:
        create_tables(conn)
        insert_data(conn, rows)
        conn.commit()