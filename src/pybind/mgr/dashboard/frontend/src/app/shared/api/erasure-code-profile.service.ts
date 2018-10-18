import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';

import { ApiModule } from './api.module';

@Injectable({
  providedIn: ApiModule
})
@Injectable()
export class ErasureCodeProfileService {
  constructor(private http: HttpClient) {}

  list() {
    return this.http.get('api/erasure_code_profile');
  }
}
