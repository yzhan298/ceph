import { HttpClientTestingModule } from '@angular/common/http/testing';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { RouterTestingModule } from '@angular/router/testing';

import { BsDropdownModule } from 'ngx-bootstrap';
import { TabsModule } from 'ngx-bootstrap/tabs';

import { configureTestBed } from '../../../../testing/unit-test-helper';
import { ComponentsModule } from '../../../shared/components/components.module';
import { Permissions } from '../../../shared/models/permissions';
import { AuthStorageService } from '../../../shared/services/auth-storage.service';
import { SharedModule } from '../../../shared/shared.module';
import { HostDetailsComponent } from './host-details/host-details.component';
import { HostsComponent } from './hosts.component';

describe('HostsComponent', () => {
  let component: HostsComponent;
  let fixture: ComponentFixture<HostsComponent>;

  const fakeAuthStorageService = {
    getPermissions: () => {
      return new Permissions({ hosts: ['read', 'update', 'create', 'delete'] });
    }
  };

  configureTestBed({
    imports: [
      SharedModule,
      HttpClientTestingModule,
      TabsModule.forRoot(),
      ComponentsModule,
      BsDropdownModule.forRoot(),
      RouterTestingModule
    ],
    providers: [{ provide: AuthStorageService, useValue: fakeAuthStorageService }],
    declarations: [HostsComponent, HostDetailsComponent]
  });

  beforeEach(() => {
    fixture = TestBed.createComponent(HostsComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
