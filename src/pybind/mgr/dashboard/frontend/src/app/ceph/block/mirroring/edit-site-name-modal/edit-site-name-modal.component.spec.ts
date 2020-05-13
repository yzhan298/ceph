import { HttpClientTestingModule } from '@angular/common/http/testing';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ReactiveFormsModule } from '@angular/forms';
import { RouterTestingModule } from '@angular/router/testing';

import { BsModalRef, BsModalService } from 'ngx-bootstrap/modal';
import { ToastrModule } from 'ngx-toastr';
import { of } from 'rxjs';

import { configureTestBed, i18nProviders } from '../../../../../testing/unit-test-helper';
import { RbdMirroringService } from '../../../../shared/api/rbd-mirroring.service';
import { NotificationService } from '../../../../shared/services/notification.service';
import { SharedModule } from '../../../../shared/shared.module';
import { EditSiteNameModalComponent } from './edit-site-name-modal.component';

describe('EditSiteNameModalComponent', () => {
  let component: EditSiteNameModalComponent;
  let fixture: ComponentFixture<EditSiteNameModalComponent>;
  let notificationService: NotificationService;
  let rbdMirroringService: RbdMirroringService;

  configureTestBed({
    declarations: [EditSiteNameModalComponent],
    imports: [
      HttpClientTestingModule,
      ReactiveFormsModule,
      RouterTestingModule,
      SharedModule,
      ToastrModule.forRoot()
    ],
    providers: [BsModalRef, BsModalService, i18nProviders]
  });

  beforeEach(() => {
    fixture = TestBed.createComponent(EditSiteNameModalComponent);
    component = fixture.componentInstance;
    component.siteName = 'site-A';

    notificationService = TestBed.get(NotificationService);
    spyOn(notificationService, 'show').and.stub();

    rbdMirroringService = TestBed.get(RbdMirroringService);
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  describe('edit site name', () => {
    beforeEach(() => {
      spyOn(rbdMirroringService, 'getSiteName').and.callFake(() => of({ site_name: 'site-A' }));
      spyOn(rbdMirroringService, 'refresh').and.stub();
      spyOn(component.modalRef, 'hide').and.callThrough();
      fixture.detectChanges();
    });

    afterEach(() => {
      expect(rbdMirroringService.getSiteName).toHaveBeenCalledTimes(1);
      expect(rbdMirroringService.refresh).toHaveBeenCalledTimes(1);
      expect(component.modalRef.hide).toHaveBeenCalledTimes(1);
    });

    it('should call setSiteName', () => {
      spyOn(rbdMirroringService, 'setSiteName').and.callFake(() => of({ site_name: 'new-site-A' }));

      component.editSiteNameForm.patchValue({
        siteName: 'new-site-A'
      });
      component.update();
      expect(rbdMirroringService.setSiteName).toHaveBeenCalledWith('new-site-A');
    });
  });
});
