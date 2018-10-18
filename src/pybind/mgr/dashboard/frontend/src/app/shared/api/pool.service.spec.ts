import { HttpClientTestingModule, HttpTestingController } from '@angular/common/http/testing';
import { fakeAsync, TestBed, tick } from '@angular/core/testing';

import { configureTestBed } from '../../../testing/unit-test-helper';
import { PoolService } from './pool.service';

describe('PoolService', () => {
  let service: PoolService;
  let httpTesting: HttpTestingController;
  const apiPath = 'api/pool';

  configureTestBed({
    providers: [PoolService],
    imports: [HttpClientTestingModule]
  });

  beforeEach(() => {
    service = TestBed.get(PoolService);
    httpTesting = TestBed.get(HttpTestingController);
  });

  afterEach(() => {
    httpTesting.verify();
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });

  it('should call getList', () => {
    service.getList().subscribe();
    const req = httpTesting.expectOne(apiPath);
    expect(req.request.method).toBe('GET');
  });

  it('should call getInfo', () => {
    service.getInfo().subscribe();
    const req = httpTesting.expectOne(`${apiPath}/_info`);
    expect(req.request.method).toBe('GET');
  });

  it('should call create', () => {
    const pool = { pool: 'somePool' };
    service.create(pool).subscribe();
    const req = httpTesting.expectOne(apiPath);
    expect(req.request.method).toBe('POST');
    expect(req.request.body).toEqual(pool);
  });

  it('should call update', () => {
    service.update({ pool: 'somePool', application_metadata: [] }).subscribe();
    const req = httpTesting.expectOne(`${apiPath}/somePool`);
    expect(req.request.method).toBe('PUT');
    expect(req.request.body).toEqual({ application_metadata: [] });
  });

  it('should call delete', () => {
    service.delete('somePool').subscribe();
    const req = httpTesting.expectOne(`${apiPath}/somePool`);
    expect(req.request.method).toBe('DELETE');
  });

  it(
    'should call list without parameter',
    fakeAsync(() => {
      let result;
      service.list().then((resp) => (result = resp));
      const req = httpTesting.expectOne(`${apiPath}?attrs=`);
      expect(req.request.method).toBe('GET');
      req.flush(['foo', 'bar']);
      tick();
      expect(result).toEqual(['foo', 'bar']);
    })
  );

  it(
    'should call list with a list',
    fakeAsync(() => {
      let result;
      service.list(['foo']).then((resp) => (result = resp));
      const req = httpTesting.expectOne(`${apiPath}?attrs=foo`);
      expect(req.request.method).toBe('GET');
      req.flush(['foo', 'bar']);
      tick();
      expect(result).toEqual(['foo', 'bar']);
    })
  );
});
