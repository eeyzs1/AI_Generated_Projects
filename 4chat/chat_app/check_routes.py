from main import app

print('All routes:')
for route in app.routes:
    print(route.path)